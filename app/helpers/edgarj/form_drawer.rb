# coding: UTF-8

module Edgarj
  module FormDrawer
    # Edgarj::FormDrawer::Base draws HTML table tag based data entry form.
    # This also provides default methods for SearchFormDrawer search condition
    # entry form.
    #
    # === How to Customize
    # 1. First, it may be enough to just redefine @options
    # 1. Next, when draw_ATTR() is defined, it is called.  See ModelPermissionControllerHelper for example.
    # 1. Then, consider to overwrite draw_ATTR() method.
    class Base
      attr_accessor :vc, :f

      # === INPUTS
      # drawer::  Edgarj::Drawer instance
      # record::  instance of AR
      # f::       FormBuilder
      def initialize(drawer, record, f)
        @drawer = drawer
        @vc     = drawer.vc   # just short-cut
        @record = record
        @f      = f

        # define default options for draw_X() method, where X is :flags, :kind,
        # and so on.  @options can be redefined at derived class.
        @options  = {
          :flags      => {},
          :kind       => {},
          :boolean    => {},
          :default    => {
            :date     => {:use_month_numbers=>true},
            :integer  => {:size=>16},
            :text     => {:size=>20},
          }
        }
      end

      # draw form
      #
      # I18n for label is:
      #
      # 1. usual column uses model.human_attribute_name()
      # 1. 'belongs_to' column uses:
      # ** I18n.t('activerecord.attributes.MODEL.EXT_ID')
      # ** parent.human_name
      def draw()
        @vc.content_tag(:table) do
          @left       = true
          @vc.capture do
            for col in columns do
              @vc.concat col.field(@record, self)
            end
            @vc.concat('<td colspan=3></td>'.html_safe) if !@left
          end
        end
      end

      def draw_field(rec, col)
        draw_method = "draw_#{col.name}"
        if self.class.method_defined?(draw_method) then
          send(draw_method, col)
        elsif (enum = get_enum(col))
          draw_enum(col, enum)
        elsif (bitset = get_bitset(col))
          draw_bitset(col, bitset)
        else
          parent_model = @vc.model.belongs_to_AR(col)
          if parent_model
            _draw_belongs_to_field(parent_model, col)
          else
            _draw_field(col)
          end
        end
      end

      def columns
        drawer = @vc.drawer
        drawer.columns_for(drawer.form_columns, :form)
      end

      # base method for derived class
      def edgarj_address?(col)
        @record.class.edgarj_address?(col)
      end

      # base method for derived class
      def edgarj_file?(col)
        @record.class.edgarj_file?(col)
      end

      # return enum of the column
      #
      # Derived class must overwrite to return expected enum
      def get_enum(col)
        @vc.get_enum(@f.object.class, col)
      end

      # return bitset of the column
      #
      # Derived class must overwrite to return expected bitset
      def get_bitset(col)
        @vc.get_bitset(@f.object.class, col)
      end

      # flip field to left-lane or right-lane
      def _draw_2_lane(&block)
        result = @left ? @vc.tag(:tr, nil, true) : ''.html_safe
        result += yield
        result += '</tr>'.html_safe if !@left
        @left = !@left              # flip it
        result
      end

      # draw head(label).  SearchFormDrawer will overwrite to insert operator.
      #
      # === INPUTS
      # col::   column info
      # label:: if not-nil, label is used rather than human_attribute_name of col.name for field-label
      # block:: wrapped field-drawing logic
      #
      def _draw_head(col, label=nil, &block)
        _draw_2_lane{
          html = @vc.content_tag(:th, label || @vc.column_label(col))
          html << @vc.content_tag(:td, '')
          html << (@vc.content_tag(:td) do yield end)
          html
        }
      end

      def draw_id(col)
        ''
      end

      def draw_type(col)
        ''
      end

      def draw_created_at(col)
        ''
      end

      def draw_updated_at(col)
        ''
      end

      # draw address fields
      def draw_address(col)
        _draw_head(col){ @vc.draw_address(@f, col) }
      end

      # draw bitset checkboxes field
      def draw_bitset(col, bitset)
        _draw_head(col){ @vc.draw_bitset(@f, col, bitset, @options[:flags]) }
      end

      # draw 'belongs_to' field for AR
      def _draw_belongs_to_field(parent_model, col)
        _draw_head(col, nil){
          @vc.draw_belongs_to_field(@f, @drawer.popup_path(col), col.name)
        }
      end

      def draw_boolean(col)
        _draw_head(col){ @vc.draw_boolean(@f, col, @options[:boolean]) }
      end

      def draw_file(col)
        _draw_head(col){ @vc.draw_file(@f, col) }
      end

      def draw_enum(col, enum)
        _draw_head(col){ @vc.draw_enum(@f, col, enum) }
      end

      # draw general field
      def _draw_field(col)
        case col.type
        when :boolean
          draw_boolean(col)
        else
          _draw_head(col){ @vc.draw_field(@f, col, @options[:default]) }
        end
      end
    end

    # Search-class differs from Base-class as follows:
    # * draws the fields of ID, created_at, and updated_at for search
    # * 'kind' selection has blank-option.
    # * boolean is not checkbox.  Rather, it is selection of [nil,false,true]
    # * edgarj_file column is not drawn. 
    class Search < Base
      # === INPUTS
      # drawer::            Edgarj::Drawer instance
      # model::             SearchForm object
      # f::                 FormBuilder object
      # operator_builder::  FormBuilder object for operator
      def initialize(drawer, model, f, operator_builder)
        super(drawer, model, f)
        @operator_builder = operator_builder

        # merge options
        @options[:kind].merge!(:include_blank=>true)
        @options[:default][:date].merge!(:include_blank=>true)
      end

      # overwrite
      def columns
        drawer = @vc.drawer
        drawer.columns_for(drawer.search_form_columns, :search_form)
      end

      # overwrite
      def edgarj_address?(col)
        @record._klass_str.constantize.edgarj_address?(col)
      end

      # overwrite
      def edgarj_file?(col)
        @record._klass_str.constantize.edgarj_file?(col)
      end

      # overwrite to insert operator
      #
      def _draw_head(col, label=nil, &block)
        _draw_2_lane{
          sprintf("<th>%s</th><td>", label || @vc.column_label(col)).html_safe +

          # add operator for appropreate data type.
          if col.name == 'id'
            @vc.draw_search_operator(@operator_builder, '_id')
          else
            case col.type
            when :date, :datetime, :integer
              @vc.draw_search_operator(@operator_builder, col.name)
            else
              ''
            end
          end + '</td><td>'.html_safe + yield + '</td>'.html_safe
        }
      end

      # overwrite to draw 'id' search field
      def draw_id(col)
        _draw_head(col){ @f.text_field('_id', @options[:default][:integer]) }
      end

      # overwrite to draw created_at
      def draw_created_at(col)
        _draw_head(col){ @vc.draw_date(@f, col, @options[:default]) }
      end

      # overwrite to draw updated_at
      def draw_updated_at(col)
        _draw_head(col){ @vc.draw_date(@f, col, @options[:default]) }
      end

      # overwrite to draw address fields: TBD
      def draw_address(col)
        _draw_head(col){
          'TBD'
        }
      end

      # overwrite to draw 'belongs_to' field for SearchForm
      #
      # This is similar to Base class 'belongs_to field', but
      # * add parent 'name' hidden field at drawing.
      # * no link on parent name
      def _draw_belongs_to_field(parent_model, col)
        model = @f.object._klass_str.constantize
        parent_name = @f.object._parent && @f.object._parent[col.name]
        _draw_head(col, @vc.draw_belongs_to_label(@f, @drawer.popup_path_on_search(col), col.name, model)){
          popup_field = Edgarj::PopupHelper::PopupField.new_builder(
              @f.object_name, col.name)

          @vc.content_tag(:span, parent_name, id: popup_field.label_target) +
          @vc.hidden_field_tag(
            'edgarj_search_form[search_form_parent][%s]' % col.name,
            parent_name.blank? ? '' : parent_name,
            id: popup_field.label_hidden_field) +
          @vc.draw_belongs_to_clear_link(@f, col.name, popup_field,
              parent_name,
              '[' + @vc.draw_belongs_to_label_sub(model, col.name, parent_model) + ']')
        }
      end

      # overwrite because it is totally different from checkbox on search.
      def draw_boolean(col)
        _draw_head(col){
          @f.select(col.name, [
              ['(both)',  ''],
              ['',        'false'],
              ['√',       'true']])
        }
      end

      # overwrite to return enum of the column in SearchForm
      #
      # see overwritten draw_enum() also.
      def get_enum(col)
        @vc.get_enum(@record._klass_str.constantize, col)
      end

      # overwrite to add '(all)' at top of enum selection for search.
      #
      # see overwritten get_enum() also.
      def draw_enum(col, enum)
        _draw_head(col){
          @vc.draw_enum(@f, col, enum,
              :choice_1st => ['(all)',''],
              :class      => @record._klass_str.constantize
              )
        }
      end

      # overwrite to disable file upload column
      def draw_file(col)
        ''
      end
    end
  end
end
