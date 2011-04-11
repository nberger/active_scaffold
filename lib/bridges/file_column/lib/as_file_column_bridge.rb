require 'active_scaffold/data_structures/column'
module ActiveScaffold::DataStructures
  class Column
    attr_accessor :file_column_display
  end
end

module ActiveScaffold::Config
  class Core < Base
    attr_accessor :file_column_fields
    def initialize_with_file_column(model_id)
      initialize_without_file_column(model_id)
      
      return unless FileColumnHelpers.klass_has_file_column_fields?(self.model)
      
      self.model.send :extend, FileColumnHelpers
      
      # include the "delete" helpers for use with active scaffold, unless they are already included
      self.model.generate_delete_helpers
      
      # switch on multipart
      self.update.multipart = true
      self.create.multipart = true
      
      self.model.file_column_fields.each{ |field|
        configure_file_column_field(field)
      }
    end
    
    alias_method_chain :initialize, :file_column unless self.instance_methods.include?("initialize_without_file_column")
    
    def configure_file_column_field(field)
      # set list_ui first because it gets its default value from form_ui
      self.columns[field].list_ui ||= self.model.field_has_image_version?(field, "thumb") ? :thumbnail : :download_link_with_filename
      self.columns[field].form_ui ||= :file_column
      
      # these 2 parameters are necessary helper attributes for the file column that must be allowed to be set to the model by active scaffold.
      self.columns[field].params.add "#{field}_temp", "delete_#{field}"
      
      # set null to false so active_scaffold wont set it to null
      # delete_file_column will take care of deleting a file or not.
      self.model.columns_hash[field.to_s].instance_variable_set("@null", false)
      
    rescue
      false
    end
    
  end
end

module ActionController #:nodoc:
  class Base
    # In your controller:
    #   :options => {:secure_download => true}
    #   def show
    #     active_scaffold_render_secure_download(File.join(RAILS_ROOT, 'files'))
    #   end
    # In your model:
    #   file_column :package, :root_path => File.join(RAILS_ROOT, 'files')
    def active_scaffold_render_secure_download(file_root)
      raise if params[:download].nil?
      # AST Not sure we need to assume encryption responsibility - seems like of authentication is not needed to download the files then the dev can override methods needed to encrypt/decrypt file location on the server.
      file_path = params[:download]#.decrypt!(:symmetric, :key => active_scaffold_config.secure_download_key)
      ext = File.extname(file_path).downcase.sub(/^\./, '')
      case ext
      when 'pdf'
        response.headers["Content-Type"] = 'application/pdf'
      else
        response.headers["Content-Type"] = "text/#{ext}"
      end
      response.headers["Content-disposition:"] = "inline; filename=\"#{params[:download]}\""
      render :text => File.read(File.join(file_root, file_path))
    end
 end 
end