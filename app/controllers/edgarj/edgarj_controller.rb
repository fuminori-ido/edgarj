require 'csv'

module Edgarj
  # Generic CRUD(Create/Read/Update/Delte) controller with Ajax.
  #
  # === EdgarjController v.s. ApplicationController
  # When concreate controller (e.g. CustomersController) inherits
  # EdgarjController, it has the following features:
  #
  # * CRUD with default form on Ajax
  #   * form can be customized.
  # * QBE (Query By Example) search form
  # * popup-selection on 'belongs_to' column
  # * sort on list
  # * saving search-conditions and reuse it
  #
  # If these are not necessary, just inherits ApplicationController.
  #
  # === Tasks when adding new model which is handled under EdgarjController
  # For example, when want to add Post model:
  # 1. generate edgarj:scaffold:
  #     rails generate edgarj:scaffold post name:string body:text published:boolean
  # 2. add controller entry to CONTROLLER_MENU (config/initializers/edgarj.rb)
  #
  # It will take about ~3 min.
  #
  # For the detail of customization, please see:
  #   http://sourceforge.net/apps/trac/jjedgarj/wiki/customize
  #
  # === Architecture
  # see {architecture}[link:../architecture.odp] (OpenOffice Presentation)
  #
  # === Access Control
  # There are two dimentions of access control:
  # 1. Page level (Controller level) access control.
  #    * Edgarj::UserGroup with kind==ROLE and Edgarj::ModelPermission
  #       represents access control on each controller.
  #    * Admin user, who belongs to 'admin' user_group, can access any page.
  #    * When a user belongs to a user_group (kind==ROLE) and 
  #      a model_permission belongs to the user_group, the user can
  #      access the controller which model is the model in model_permission.
  #    * More precisely, 4 kind of access controls, CREATE,
  #      READ, UPDATE, and DELETE can be set with any conbination on the
  #      controller.
  #    * See Edgarj::ModelPermission for more detail.
  # 1. Data scope.
  #    * data scope access is controlled by 'user_scoped(user, context)'
  #      scope defined at each model.
  #    * Where, user is currently accessing person to the model.
  #    * context is any kind of 2nd parameter.  Default is session object of
  #      Edgarj::Sssn, but it can be overwritten 'scope_context' method
  #      at the target controller.
  #    * See Author.user_scoped as an example.
  #
  # == Naming Convention
  #
  # * 'record' is an instance of 'Model'.
  # * 'drawer' is an instance of 'Drawer' class.
  #
  # === Implementation Note
  # Why not to choose mixin rather than class is because
  # it is easier to use edgarj's view at client controller.  For example,
  # AuthorsController, which inherits from EdgarjController, can
  # automatically use edgarj's view by rails view-selection feature.
  #
  # === SEE ALSO
  # PopupController::  'belongs_to' popup for EdgarjController
  # 
  class EdgarjController < ApplicationController
    include ControllerMixinCommon
    include PermissionMixin
   #include TopicPathControllerMixin

    helper_method :model, :model_name, :drawer,
        :draw_flash, :csv_proc

    READ_ACTIONS = %w(
        index show clear search search_clear search_save search_load
        zip_complete csv_download file_download map page_info_save)

    before_filter :require_create_permission, only: :create
    before_filter :require_read_permission,   only: READ_ACTIONS
    before_filter :require_update_permission, only: :update
    before_filter :require_delete_permission, only: :destroy
    before_filter :require_other_permission,  except: READ_ACTIONS + %w(
      create update destroy top)
   #after_filter  :log_topic_path
    after_filter  :enum_cache_stat

    # This page is for following purposes:
    #
    # * top page which contain latest info (TBD)
    # * any error message on HTML format access
    #   * on Ajax access, rather edgarj_error_popup is used
    def top
      render :action => 'top'
    end

    # draw search result in whole page.
    # default update DOM id and template is as follows:
    #
    # DOM id::   'edgarj_list'
    # template:: 'edgarj/list'
    #
    # However, these can be replaced by params[:update] and params[:template]
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    #
    # === SEE ALSO
    # popup():: draw popup
    def index
      page_info

      # update @page_info.page when page is specified.
      # Otherwise, reset page to 1.
      #
      # Just set, not save.  It will be done later when saving sssn with
      # 'has_many page_infos ... autosave: true'
      @page_info.page = (params[:page] || 1)

     #clear_topic_path
      prepare_list

      @search = page_info.record
      @record = model.new
    end

    # save new record
    #
    # === Permission
    # ModelPermission::CREATE on this controller is required.
    #
    def create
      upsert do
        # NOTE: create!() is not used because assign to @record to draw form.
        # Otherwise, @record would be in nil so failure at edgarj/_form rendering.
        #
        # NOTE2: valid? after create() calls validate_on_update.  This is not
        # an expected behavior.  So, new, valid?, then save.
        @record = model.new(permitted_params(:create))
        @record_saved = @record     # copy for possible later use
        on_upsert
       #upsert_files
        raise ActiveRecord::RecordNotSaved if !@record.valid?
        @record.save

        # clear @record values for next data-entry
        @record = model.new
      end
    end

    # Show detail of one record.  Format of html & js should be supported.
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    #
    def show
      @record = user_scoped.find(params[:id])
     #add_topic_path
      respond_to do |format|
        format.html {
          prepare_list
          @search = page_info.record
          render :action=>'index'
        }
        format.js
      end
    end

    # save existence modified record
    #
    # === Permission
    # ModelPermission::UPDATE on this controller is required.
    #
    def update
      upsert do
        # NOTE:
        # 1. update ++then++ valid to set new values in @record to draw form.
        # 1. user_scoped may have joins so that record could be
        #    ActiveRecord::ReadOnlyRecord so that's why access again from
        #    model.
        @record  = model.find(user_scoped.find(params[:id]).id)
       #upsert_files
        if !@record.update_attributes(permitted_params(:update))
          raise ActiveRecord::RecordInvalid.new(@record)
        end
      end
    end

    # === Permission
    # ModelPermission::DELETE on this controller is required.
    def destroy
      m = model.find(user_scoped.find(params[:id]).id)
      @record_saved = m     # copy for possible later use
      m.destroy

      prepare_list
      @record = model.new
      @flash_notice = t('delete_ok')
    end

    # Ajax method to clear form
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    #
    def clear
      @record = model.new
    end

    # Ajax method to execute search
    #
    # Actually, this doesn't execute search.  Rather, this just saves
    # condition.  Search will be executed at any listing action
    # like 'index', 'create', or 'update'.
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    #
    def search
      pi        = page_info
      pi.record = SearchForm.new(model, params[:edgarj_search_form])
      pi.page = 1
      pi.save!
      @search   = pi.record
      prepare_list if @search.valid?
    end

    # Ajax method to clear search conditions
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    #
    def search_clear
      @search   = SearchForm.new(model)
    end

    # Ajax method to save search conditions
    #
    # === call flow
    #  Edgarj.SearchSavePopup.open() (javascript)
    #   (show $('search_save_popup'))
    #    Edgarj.SearchSavePopup.submit() (javascript)
    #     (copy entered name into $('saved_page_info_name') in form)
    #      call :action=>'search_save'
    #
    # ==== TRICKY PART
    # There are two requirements:
    # 1. use modal-dialog to enter name to decrese busy in search form.
    # 1. send Search Form with name to server.
    #
    # To comply these, Edgarj.SearchSavePopup copies the entered name to
    # 'saved_page_info_name' hidden field and then sends the form which includes
    # the copied name.
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    #
    def search_save
      SavedVcontext.save(current_user, nil,
                         params[:saved_page_info_name], page_info)

      render :update do |page|
        page << "Edgarj.SearchSavePopup.close();"
        page.replace 'edgarj_load_condition_menu',
           :partial=>'edgarj/load_condition_menu'
      end
    rescue ActiveRecord::ActiveRecordError
      app_rescue
      render :update do |page|
        page.replace_html 'search_save_popup_flash_error', :text=>t('save_fail')
      end
    end

    # Ajax method to load search condition, lines, order_by, dir, and page.
    #
    def search_load
      @search = current_user.saved_page_infos.find(params[:id]).load(@sssn).model
      draw_search_form
    end

    # zip -> address completion
    #
    # === INPUTS
    # params[:zip]::          key to find address info. hyphen is supported.
    # params[:adrs_prefix]::  address fields DOM id prefix. e.g. 'org_adrs_0_'
    #
    # === call flow
    # ==== on drawing
    #   EdgarjHelper.draw_adrs()       app/helpers/edgarj_helper.rb
    #                                 app/views/edgarj/_address.html.erb
    #       Example:
    #           :
    #       <input type=text name='org[adrs_0_zip]'>
    #           :
    #
    # ==== on clicking zip->address button
    #   Edgarj.zip_complete()          public/javascripts/edgarj.js
    #    Ajax.Request()
    #     EdgarjController.zip_complete  app/controllers/edgarj_controller.rb
    #      inline RJS to fill address info
    #
=begin
    def zip_complete
      zip           = params[:zip].gsub(/\D/, '')
      @address      = ZipAddress.find_by_zip(zip) || ZipAddress.new(
                        :prefecture => '?',
                        :city       => '',
                        :other      => '')

      # sanitize
      @adrs_prefix  = params[:adrs_prefix].gsub(/[^a-zA-Z_0-9]/, '')
    end
=end

    # download model under current condition
    #
    # <tt>respond_to...format.csv</tt> approach was not used since
    # \@list is different as follows:
    # * csv returns all of records under the conditions
    # * HTML returns *just* in specified 'page'.
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    #
    # FIXME: file.close(true) deletes files *BEFORE* actually send file
    # so that comment it out.  Need to clean these work files.
    def csv_download
      dir = '/tmp/edgarj/csv_download'
      FileUtils.mkdir_p(dir)

      filename    = sprintf("%s-%s.csv",
                        model_name,
                        Time.now.strftime("%Y%m%d-%H%M%S"))
      file        = Tempfile.new(filename, dir)
      csv_visitor = EdgarjHelper::CsvVisitor.new(view_context)
      file.write CSV.generate_line(model.columns.map{|c| c.name})
      for rec in user_scoped.where(page_info.record.conditions).
          order(
            page_info.order_by.blank? ?
              nil :
              page_info.order_by + ' ' + page_info.dir) do
        array = []
        for col in model.columns do
          array << csv_visitor.visit_column(rec, col)
        end
        file.write CSV.generate_line(array)
      end
      file.close
      send_file(file.path, {
          type:     'text/csv',
          filename: filename})
     #file.close(true)
    end

    # To prevent unassociated file access, do:
    #
    # 1. check if it is in model object
    # 1. check if it is a edgarj_file column
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    def file_download
      if !model.edgarj_file?(params[:column])
        flash[:error] = t('edgarj_file.no_assoc')
        return
      end

      file_info_id = user_scoped.find(params[:id]).send(params[:column])
      if file_info_id
        file_info = FileInfo.find(file_info_id)
        if file_info
          send_file(file_info.full_filename, :filename => file_info.filename)
          return
        end
      end
      logger.warn 'invalid file_info'
    end

    # draw Google map.
    #
    # === Permission
    # ModelPermission::READ on this controller is required.
    #
    def map
      render :template=>'edgarj/map', :layout=>false
    end

  private
    # derive model class from this controller.
    #
    # If controller cannot guess model class, overwrite this.
    #
    # === Examples:
    # * AuthorsController   -> Author
    # * UsersController     -> User
    def model
      @_model ||=
        if self.class == Edgarj::EdgarjController
          # dummy model for 'top' action:
          Edgarj::Sssn
        else
          self.class.name.gsub(/Controller$/, '').singularize.constantize
        end
    end

    # return model name.
    #
    # if each concreate controller cannot guess model name from its
    # controller name, overwrite this.
    #
    # === Examples:
    # * UsersController     -> 'edgarj_user'
    # * AuthorsController   -> 'author'
    # 
    def model_name
      @_model_name ||= ActiveModel::Naming.param_key(model.new)
    end

    # return permitted params.  Default is all.
    #
    # Derived Controller *MUST* customize this.
    def permitted_params(action, kind=nil)
      params.require(model_name).permit!
    end

    # return search-form object.
    #
    # called from page_info
    def search_form
      SearchForm.new(model)
    end

    # derive drawer class from this controller.
    #
    # If controller cannot guess drawer class, overwrite this.
    #
    # === Examples:
    # * AuthorsController   -> AuthorDrawer
    # * UsersController     -> UserDrawer
    def drawer_class
      @_drawer_cache ||=
        if self.class == Edgarj::EdgarjController
          Edgarj::Drawer::Normal
        else
          (self.class.name.gsub(/Controller$/, '').singularize +
              'Drawer').constantize
        end
    end

    # set drawer instance as drawer for later use on rendering view
    def set_drawer
      @drawer = drawer_class.new(view_context, params, page_info, model)
    end

    def drawer
      @drawer
    end

    # additional behavior on upsert (default does nothing).
    #
    # Derived controller may overwrite this method if necessary, for example:
    # * to upsert protected attributes.
    # * to upsert server-side calculated values
    def on_upsert
      #
    end

    # update/insert common
    def upsert(&block)
      ActiveRecord::Base.transaction do
        yield
        @flash_notice = t('save_ok')
      end
      prepare_list
    rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => ex
      logger.info "#{ex.class.to_s}: #{@record.class.to_s}: #{@record.errors.full_messages.join(' / ')}"
      app_rescue
      @flash_error = t('save_fail')
    end

    # At public action, just set any message into @flash_notice and/or
    # \@flash_error.  Then, any render in EdgarjController will display it
    # by calling draw_flash().
    #
    # draw_flash() must be a helper because it is called in render block, which
    # is a kind of view.
    def draw_flash(page)
      page.replace_html 'flash_notice', :text=>@flash_notice
      page.replace_html 'flash_error',  :text=>@flash_error
    end

    # insert/update uploaded file and point to it via file_NN column
=begin
    def upsert_files
     #@record.upsert_files(params[:file_info], params[model_name])
    end

    # Since 'render :text=>proc...' cannot be tested at functional test
    # (see http://lightyearsoftware.com/2009/10/rails-bug-with-render-text-proc-in-tests/),
    # move the logic inside the proc here to test
    def csv_proc(output)
      csv_visitor = EdgarjHelper::CsvVisitor.new(@template)
      find_args = {:conditions=>page_info.record.conditions}
      if !page_info.order_by.blank?
        find_args.merge!(:order => page_info.order_by + ' ' + page_info.dir)
      end
      output.write CSV.generate_line(model.columns.map{|c| c.name}) + "\n"
      for rec in model.find(:all, find_args) do
        array = []
        for col in model.columns do
          array << csv_visitor.visit_column(rec, col)
        end
        output.write CSV.generate_line(array) + "\n"
      end
    end
=end

    # This works as:
    #
    #   before_render :set_drawer
    #
    # to set drawer just before rendering.
    #
    # See http://stackoverflow.com/questions/9281224/filter-to-execute-before-render-but-after-controller
    #
    def render(*args)
      # set_drawer should be called only when finishing before_filters.
      set_drawer if current_user
      super
    end

    def enum_cache_stat
      logger.debug 'EnumCache stat (hit/out/out_of_enum): ' +
          EnumCache.instance.stat.inspect
    end
  end
end
