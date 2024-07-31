module Edgarj
  module AssocHelper
=begin
    # remote_function + spinner
    def edgarj_remote_function(url, method='get')
      "Edgarj._simple_ajax('#{j(url_for(url))}', '#{method}')"
    end

    # form_for which supports Ajax-like file upload.
    #
    # In order to support Ajax-like file upload, use
    # form-target-iframe-responds_to_parent mechanism.
    def edgarj_form(&block)
      url_hash = {
        controller: params[:controller],
        action:     @model.new_record? ? 'create' : 'update',
        format:     :js
      }
      url_hash[:id] = @model.id if @model.persisted?
      form_for(@model,
          remote: true,
          url:    url_hash,
          html:   {
              id:         '_edgarj_form',
              method:     @model.new_record? ? 'post' : 'put',
              multipart:  true,
             #target:     'edgarj_form_frame'
          }, &block)
    end

    # According to http://khamsouk.souvanlasy.com/articles/ajax_file_uploads_in_rails
    # 'display:none' style should *NOT* used:
    def iframe_for_edgarj_form
      %Q(<iframe id=edgarj_form_frame name=edgarj_form_frame
        style='width:1px;height:1px;border:0px' src='about:blank'></iframe>
      ).html_safe
    end

    # === INPUTS
    # o::       operator form builder
    # method::  column name
    def draw_search_operator(o, method)
      render '/edgarj/search_operator',
          o:        o,
          method:   method
    end

    # Edgarj standard datetime format
    def datetime_fmt(dt)
      if dt.blank? then
        ''
      else
        I18n.l(dt, format: I18n.t('edgarj.time.format'))
      end
    end

    # Edgarj standard date format
    def date_fmt(dt)
      if dt == nil then
        ''
      else
        dt.strftime(I18n.t('date.formats.default'))
      end
    end

    def draw_view_status_load_menu
      content_tag(:div, :id=>'edgarj_load_condition_menu', :class=>'edgarj_menu') do
        content_tag(:table) do
          content_tag(:tr) do
            if current_user.saved_view_statuss.count(:conditions=>['view=?', controller_name]) > 0
              draw_menu_top_and_pulldown('saved_conditions', t('load_condition')) do
                out = ""
                for svc in current_user.saved_view_statuss.find_all_by_view(controller_name) do
                  out += edgarj_link_to_remote(
                                svc.name, {:action=>'search_load', :id=>svc.id})
                end
                out
              end
            else
              # not to draw empty sub menu of 'saved_conditions' 
              ''
            end +
            content_tag(:td) do
              link_to 'Help', url_for(:controller=>'/help',
                                :action=>'search.html'), {:target=>'help'}
            end
          end
        end
      end
    end

    # draw sort link on list column header
    #
    # === INPUTS
    # col::         column data
    # options::     options to url_for
    def draw_sort(col, options={})
      label = model_class.human_attribute_name(col.name)
      dir   = 'asc'
      if @view_status.order_by == col.name
        # toggle direction
        if @view_status.dir == 'asc' || @view_status.dir.blank?
          label += '▲'
          dir    = 'desc'
        else
          label += '▼'
        end
      end
      link_to(label,
          {
          :controller                   => params[:controller],
          :action                       => 'view_status_save',
          :id                           => @view_status.id,
          'edgarj_view_status[order_by]' => col.name,
          'edgarj_view_status[dir]'      => dir
          }.merge(options),
          :remote => true,
          :method => :put)
    end
=end

    # 1. t('view.CONTROLLER.MODEL.COL_NAME')
    # 1. MODEL.human_attribute_name(COL_NAME)
    # 1. else, parent.human_name is used.
    def draw_belongs_to_label_sub(model, col_name, parent_model)
      @controller_model ||= controller.send(:model)

      I18n.t(col_name,
          scope:    "view.#{controller_path}.#{@controller_model.name.underscore}",
          default:  model.human_attribute_name(col_name,
              default:  parent_model.human_name))
    end

=begin
    # draw belongs_to name.  When link=true(default), draw it as hyper-link
    def draw_belongs_to(parent_obj, link=true)
        if link
          link_to( parent_obj.name,
              controller: '/' + parent_obj.class.name.underscore.pluralize,
              action:     'show',
              id:         parent_obj.id)
        else
          h(parent_obj.name)
        end
    end
=end

    # draw 'belongs_to' popup button(link) label.  This is used at:
    #
    # * edgarj form for data entry
    # * edgarj search form(Edgarj::SearchForm) for search-condition entry
    #
    # === INPUTS
    # @param f          [FormBuilder] FormBuilder object
    # @param popup_path [String]      popup path(url)
    # @param col_name   [String]      'belongs_to' column name
    # @param model      [AR]          data model class
    def draw_belongs_to_label(f, popup_path, col_name, model = f.object.class)
      col   = model.columns.detect{|c| c.name == col_name.to_s}
      return "no column found" if !col

      parent_model = model.belongs_to_AR(col)
      return "parent_model is nil" if !parent_model

      link_to(
          draw_belongs_to_label_sub(model, col.name, parent_model).html_safe +
          '<span class="edgarj_field_belongs_to_button">▼</span>'.html_safe,
          popup_path,
          remote: true)
    end

    # draw 'clear' link for 'belongs_to' popup data-entry field
    #
    # === INPUTS
    # f::           FormBuilder object
    # col_name::    'belongs_to' column name
    # popup_field:: Edgarj::PopupHelper::PopupField object
    # parent_name:: initial parent name
    def draw_belongs_to_clear_link(f, col_name, popup_field, parent_name, default_label)
      ('&nbsp;&nbsp;' +
          link_to("[#{I18n.t('edgarj.default.clear')}]", '#',
              onClick:  "Edgarj.Popup.clear('#{j(popup_field.id_target)}','#{j(default_label)}'); return false;",
              id:       popup_field.clear_link,
              style:    'display:' + (parent_name.blank? ? 'none' : '')) +
          f.hidden_field(col_name)).html_safe
    end

    # draw 'belongs_to' popup data-entry field
    #
    # This is usually used with draw_belongs_to_label().
    #
    # @param f          [FormBuilder] FormBuilder object
    # @param popup_path [String]      popup path(url)
    # @param col_name   [String]      'belongs_to' column name
    # @param model      [AR]          data model class
    def draw_belongs_to_field(f, popup_path, col_name, model = f.object.class)
      col   = model.columns.detect{|c| c.name == col_name.to_s}
      return "no column found" if !col

      parent_model = model.belongs_to_AR(col)
      return "parent_model is nil" if !parent_model

      parent_obj  = f.object.belongs_to_AR(col)
      popup_field = Edgarj::PopupHelper::PopupField.new_builder(
          f.object_name, col_name)
      default_label = '[' + draw_belongs_to_label_sub(model, col.name, parent_model) + ']'
      label = content_tag(:span,
          parent_obj ? parent_obj.name : default_label.html_safe,
          id: popup_field.label_target)
      link_tag = '<span class="edgarj_field_belongs_to_button">▼</span>'.html_safe
      if parent_obj
        link_to(
            label + link_tag,
            popup_path,
            remote: true)
      else
        link_to(
            label + link_tag,
            popup_path,
            remote: true)
      end +
      draw_belongs_to_clear_link(f, col.name, popup_field,
          parent_obj && parent_obj.name,
          default_label)
    end

    # Is flag in column_value on?
    def flag_on?(column_value, bitset, flag)
      val = column_value || 0
      (val & bitset.const_get(flag)) != 0
    end

    # get bitset Module.
    #
    # When ColBitset(camelized argument col name + 'Bitset') module exists,
    # the ColBitset is assumed enum definition.
    def get_bitset(model, col)
      bitset_name = col.name.camelize + 'Bitset'
      if model.const_defined?(bitset_name, false)
        _module = model.const_get(bitset_name)
        _module.is_a?(Module) ? _module : nil
      else
        nil
      end
    end

    # draw bitset column in list.
    #
    # === INPUTS
    # rec::         AR object
    # col_or_sym::  column object returned by rec.class.columns
    # bitset::      Module which contains bitset constants
    #
    # === SEE ALSO
    # get_bitset()::        get bitset definition
    # draw_bitset()::       draw bitste checkboxes field
    # draw_column_enum()::  draw bitset column in list
    def draw_column_bitset(rec, col_or_sym, bitset)
      turn_on_flags = []
      value         = rec.send(get_column_name(col_or_sym))
      for flag in bitset.constants do
        turn_on_flags << flag if flag_on?(value, bitset, flag)
      end
      turn_on_flags.map{|f| rec.class.human_const_name(bitset, f) }.join(' ')
    end

    # draw enum column in list.
    #
    # When enum for col is defined, constant string (rather than rec.col value)
    # is drawn.  See get_enum() for more detail of enum for the col.
    #
    # === EXAMPLE
    # Question has status attribute and Question::Status enum.
    # When question.status == 300,
    # draw_column_enum(question, status_col, Question::Status) returns
    # I18n.t('WORKING').
    #
    # Where:
    # * question is Question AR object.
    # * status_col is one of Question.columns object for status column.
    #
    # === INPUTS
    # rec::         AR object
    # col_or_sym::  column object returned by rec.class.columns
    # enum::        Module which contains constants
    #
    # === SEE ALSO
    # get_enum()::            get enum definition
    # draw_enum()::           draw enum selection field
    # draw_column_bitset()::  draw bitset column in list
    #
    def draw_column_enum(rec, col_or_sym, enum)
      Edgarj::EnumCache.instance.label(rec, get_column_name(col_or_sym), enum)
    end

    # return address element string or ''
    def adrs_str_sub(model, prefix, element)
      e = model.send(prefix + element)
      e.blank? ? '' : e
    end

    # model & adrs_prefix -> address string
    def adrs_str(model, adrs_prefix)
      result = ''
      for adrs_element in ['prefecture', 'city', 'other', 'bldg'] do
        result << adrs_str_sub(model, adrs_prefix, adrs_element)
      end
      result
    end

    # return true if login user has enough permission on current controller.
    def permitted?(requested_flags = 0)
      current_user_roles.any?{|ug| ug.admin?} ||
      current_model_permissions.any?{|cp| cp.permitted?(requested_flags)}
    end

    # return true if login user has any permission on the controller.
    def permitted_on?(controller)
      true  # TBD
    end

    # Visit @list and generate csv
    class CsvVisitor
      # === INPUTS
      # t:: template object
      def initialize(t)
        @t = t
      end

      def visit_column(rec, col)
        val = rec.send(col.name)
        case col.type
        when :date
          @t.date_fmt(val)
        when :datetime
          @t.datetime_fmt(val)
        else
          rec.send(col.name)
        end
      end
    end

  private
    def top_menu_td(id, name)
      content_tag(:td,
        :id           => id,
        :onMouseOver  => "Edgarj.Menu.show('#{id}')",
        :onMouseOut   => "Edgarj.Menu.hide('#{id}')") do

        content_tag(:a, name, :href=>'#') + yield
      end
    end

    # Provide consistency between <td> tag id and its sub contents <div> id.
    # This concistency is required for javascript pull-down action.
    def draw_menu_top_and_pulldown(id, name)
      top_menu_td(id, name) do
        content_tag(:div, :class=>'submenu', :id=>"sub#{id}") do
          yield
        end
      end
    end
  end
end
