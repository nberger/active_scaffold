module ActiveScaffold::Actions
  module Refresh
    def self.included(base)
      base.before_filter :list_authorized?
    end

    def refresh
      respond_to do |type|
        type.js do
          do_list
          render :update do |page|
            page[active_scaffold_content_id].replace_html render(:partial => 'list', :layout => false)
          end
        end
        type.html { return_to_main }
      end
    end
    
    protected

  end
end
