module ActiveScaffold::Actions
  module PrintList
    include ActiveScaffold::Search
    include ActiveScaffold::Actions::PrintBase

    def self.included(base)
      base.before_filter :print_list_authorized_filter, :only => [:print_list]
    end

    def print_list
      do_print_list active_scaffold_config.print_list

      respond_to do |type|
        type.html {
          render(:partial => 'print_list', :layout => false)
        }
        # not working
        # type.pdf {
        #   @html = render_to_string(:partial => "print_list.html.erb", :layout => false)
        #   prawnto :prawn => {:page_layout => :landscape}, :inline => true
        #   render :layout => false
        # }
        type.xml { render :xml => response_object.to_xml, :content_type => Mime::XML, :status => response_status }
        type.json { render :text => response_object.to_json, :content_type => Mime::JSON, :status => response_status }
        type.yaml { render :text => response_object.to_yaml, :content_type => Mime::YAML, :status => response_status }
      end
    end

    protected
   
    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def print_list_authorized?
      authorized_for?(:action => :read)
    end

    private

    def print_list_authorized_filter
      raise ActiveScaffold::ActionNotAllowed unless print_list_authorized?
    end
    
  end
end