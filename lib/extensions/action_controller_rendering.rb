# wrap the action rendering for ActiveScaffold controllers
module ActionController #:nodoc:
  class Base
    def render(options = nil, extra_options = {}, &block) #:doc:
      raise DoubleRenderError, "Can only render or redirect once per action" if performed?

      if options.nil?
        return render(:file => default_template_name, :layout => true)
      elsif !extra_options.is_a?(Hash)
        raise RenderError, "You called render with invalid options : #{options.inspect}, #{extra_options.inspect}"
      else
        if options == :update
          options = extra_options.merge({ :update => true })
        elsif !options.is_a?(Hash)
          raise RenderError, "You called render with invalid options : #{options.inspect}"
        end
      end

      response.layout = layout = pick_layout(options)
      logger.info("Rendering template within #{layout}") if logger && layout

      if content_type = options[:content_type]
        response.content_type = content_type.to_s
      end

      if location = options[:location]
        response.headers["Location"] = url_for(location)
      end

      if options.has_key?(:text)
        text = layout ? @template.render(options.merge(:text => options[:text], :layout => layout)) : options[:text]
        render_for_text(text, options[:status])

      else
        if file = options[:file]
          render_for_file(file, options[:status], layout, options[:locals] || {})

        elsif template = options[:template]
          render_for_file(template, options[:status], layout, options[:locals] || {})

        elsif inline = options[:inline]
          render_for_text(@template.render(options.merge(:layout => layout)), options[:status])

        elsif action_name = options[:action]
          render_for_file(default_template_name(action_name.to_s), options[:status], layout)

        elsif xml = options[:xml]
          response.content_type ||= Mime::XML
          render_for_text(xml.respond_to?(:to_xml) ? xml.to_xml : xml, options[:status])

        elsif js = options[:js]
          response.content_type ||= Mime::JS
          render_for_text(js, options[:status])

        elsif json = options[:json]
          json = json.to_json unless json.is_a?(String)
          json = "#{options[:callback]}(#{json})" unless options[:callback].blank?
          response.content_type ||= Mime::JSON
          render_for_text(json, options[:status])

        elsif options[:partial]
          options[:partial] = default_template_name if options[:partial] == true
          if layout
            render_for_text(@template.render(:text => @template.render(options), :layout => layout), options[:status])
          else
            render_for_text(@template.render(options), options[:status])
          end

        elsif options[:update]
          @template.send(:_evaluate_assigns_and_ivars)

          generator = ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.new(@template, &block)
          response.content_type = Mime::JS
          render_for_text(generator.to_s, options[:status])

        elsif options[:nothing]
          render_for_text(nil, options[:status])

        else
          render_for_file(default_template_name, options[:status], layout)
        end
      end
    end
    
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