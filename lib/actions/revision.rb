# 
# Works with acts_as_revisionable plugin
# 
module ActiveScaffold::Actions
  module Revision
    def self.included(base)
      base.before_filter :revision_authorized?, :only => :revision
    end

    def revision
      do_revision

      successful?
      respond_to do |type|
        type.html { render :action => 'revision', :layout => true }
        type.js { render :partial => 'revision', :layout => false }
        type.xml { render :xml => response_object.to_xml, :content_type => Mime::XML, :status => response_status }
        type.json { render :text => response_object.to_json, :content_type => Mime::JSON, :status => response_status }
        type.yaml { render :text => response_object.to_yaml, :content_type => Mime::YAML, :status => response_status }
      end
    end

    def next_revision
      @revision_number = params[:revision_number].to_i + 2 if params[:revision_number]
      revision
    end
    
    def previous_revision
      @revision_number = params[:revision_number].to_i - 2 if params[:revision_number]
      revision
    end
    
    protected

    # A simple method to retrieve and prepare a record for revisioning.
    # May be overridden to customize revision routine
    def do_revision
      @record = find_if_allowed(params[:id], :read)
      @current_revision_number = @record.current_revision_number
      @revision_number ||= @current_revision_number
      @rev_record_1 = @record.restore_revision(@revision_number) if @revision_number
      @rev_record_2 = @record.restore_revision(@revision_number - 1) if @revision_number > 1
    end

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def revision_authorized?
      authorized_for?(:action => :read)
    end
  end
end