module ActiveScaffold::Actions
  module Refresh
    def self.included(base)
      base.before_filter :refresh_authorized?
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

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def refresh_authorized?
      authorized_for?(:action => :read)
    end
    private
    def refresh_authorized_filter
      raise ActiveScaffold::ActionNotAllowed unless refresh_authorized?
    end
  end
end
