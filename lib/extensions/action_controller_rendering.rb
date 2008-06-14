# wrap the action rendering for ActiveScaffold controllers
module ActionController #:nodoc:
  class Base
    def render_with_active_scaffold(*args, &block)
      # ACC I'm never seeing this params[:adapter] value being passed in, only args[0][:action]
      if self.class.uses_active_scaffold? and ( params[:adapter] || args[0][:action] ) and @rendering_adapter.nil?
        @rendering_adapter = true # recursion control
        # if we need an adapter, then we render the actual stuff to a string and insert it into the adapter template
        path_val = params[:adapter] || args[0][:action]
        # ACC I'm setting use_full_path to false here and rewrite_template_path_for_active_scaffold has been
        # modified to return an absolute path
        show_layout = args[0][:partial] ? false : true
        render :file => rewrite_template_path_for_active_scaffold(path_val),
               :locals => {:payload => render_to_string(args.first, &block)},
               :use_full_path => false,
               :layout => show_layout
        @rendering_adapter = nil # recursion control
      else
        render_without_active_scaffold(*args, &block)
      end
    end
    alias_method :render_without_active_scaffold, :render
    alias_method :render, :render_with_active_scaffold

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
    
    private

    def rewrite_template_path_for_active_scaffold(path)
      base = File.join RAILS_ROOT, 'app', 'views'
      # check the ActiveScaffold-specific directories
      active_scaffold_config.template_search_path.each do |template_path|
        search_dir = File.join base, template_path
        next unless File.exists?(search_dir)
        template_file = Dir.entries(search_dir).find {|f| f =~ /^#{path}/ }
        return File.join(search_dir, template_file) if template_file and template_exists?(template_file)
      end
      return path
    end
  end
end