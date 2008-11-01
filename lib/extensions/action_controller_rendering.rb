# wrap the action rendering for ActiveScaffold controllers
module ActionController #:nodoc:
  class Base
    def render_with_active_scaffold(*args, &block)
      if self.class.uses_active_scaffold? and params[:adapter] and @rendering_adapter.nil?
        @rendering_adapter = true # recursion control
        # if we need an adapter, then we render the actual stuff to a string and insert it into the adapter template
        render :file => params[:adapter],
               :locals => {:payload => render_to_string(args.first, &block)},
               :use_full_path => true
        @rendering_adapter = nil # recursion control
      else
        render_without_active_scaffold(*args, &block)
      end
    end
    alias_method_chain :render, :active_scaffold

	# Rails 2.x implementation is post-initialization on :active_scaffold method

    # In your controller:
    #   :options => {:secure_download => true}
    #   def show
    #     active_scaffold_render_secure_download(File.join(RAILS_ROOT, 'files'))
    #   end
    # In your model:
    #   file_column :package, :root_path => File.join(RAILS_ROOT, 'files')
    def active_scaffold_render_secure_download(file_root)
      raise if params[:download].nil?
      file_path = params[:download].decrypt!(:symmetric, :key => active_scaffold_config.secure_download_key)
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