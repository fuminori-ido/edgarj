module Edgarj
  class PageInfo < ActiveRecord::Base
    self.table_name = 'edgarj_page_infos'

    belongs_to  :sssn

    def self.intern(sssn, view, search_obj)
      if !sssn || !(page_info = sssn.page_infos.find_by_view(view))
        page_info = sssn.page_infos.build(
            view:     view,
            lines:    10,
            order_by: '',
            dir:      '',
            page:     1)
        page_info.record = search_obj

        # save it to get id since id will be used later e.g.
        # @vs.link_to(... @page_info.id) in Edgarj::Drawer::Base#draw_sort
        page_info.save!
      end
      page_info
    end

    # serialize model and set it to model_data
    #
    def record=(record)
      self.record_data = Base64.encode64(Marshal.dump(record))
    end

    # de-serialize in model_data and return it
    #
    def record
      if self.record_data
        # FIXME: Following code fixes the error:
        #  - ArgumentError (undefined class/module Search)
        #  - ArgumentError (undefined class/module SearchForm)
        #
        # But some autoload may smartlier fixes this?
        Search
        SearchForm
        Marshal.load(Base64.decode64(self.record_data))
      else
        nil
      end
    end
  end
end
