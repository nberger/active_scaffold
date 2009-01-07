module ActionView
  module Helpers
    module JavaScriptMacrosHelper
      # Fix html_escape issues with url_for.
      def in_place_editor(field_id, options = {})
        function =  "new Ajax.InPlaceEditor("
        function << "'#{field_id}', "
        function << "'#{url_for(options[:url])}'".gsub("&amp;", "&")

        js_options = {}
        js_options['cancelText'] = %('#{options[:cancel_text]}') if options[:cancel_text]
        js_options['okText'] = %('#{options[:save_text]}') if options[:save_text]
        js_options['loadingText'] = %('#{options[:loading_text]}') if options[:loading_text]
        js_options['savingText'] = %('#{options[:saving_text]}') if options[:saving_text]
        js_options['rows'] = options[:rows] if options[:rows]
        js_options['cols'] = options[:cols] if options[:cols]
        js_options['size'] = options[:size] if options[:size]
        js_options['externalControl'] = "'#{options[:external_control]}'" if options[:external_control]
        js_options['loadTextURL'] = "'#{url_for(options[:load_text_url])}'" if options[:load_text_url]        
        js_options['ajaxOptions'] = options[:options] if options[:options]
        js_options['evalScripts'] = options[:script] if options[:script]
        js_options['callback']   = "function(form) { return #{options[:with]} }" if options[:with]
        js_options['clickToEditText'] = %('#{options[:click_to_edit_text]}') if options[:click_to_edit_text]
        function << (', ' + options_for_javascript(js_options)) unless js_options.empty?
  
        function << ')'

        javascript_tag(function)
      end
      
      def format_inplace_edit_column(record,column)
        value = record.send(column.name)
        if column.list_ui == :checkbox
          active_scaffold_column_checkbox(column, record)
        else
          clean_column_value(format_column(value))
        end
      end
      
      def active_scaffold_in_place_editor_js(field_id, options = {})
        function =  "new Ajax.InPlaceEditor("
        function << "'#{field_id}', "
        function << "'#{url_for(options[:url])}'"

        js_options = {}
        js_options['cancelText'] = %('#{options[:cancel_text]}') if options[:cancel_text]
        js_options['okText'] = %('#{options[:save_text]}') if options[:save_text]
        js_options['loadingText'] = %('#{options[:loading_text]}') if options[:loading_text]
        js_options['savingText'] = %('#{options[:saving_text]}') if options[:saving_text]
        js_options['rows'] = options[:rows] if options[:rows]
        js_options['htmlResponse'] = options[:html_response] if options.has_key?(:html_response)
        js_options['cols'] = options[:cols] if options[:cols]
        js_options['size'] = options[:size] if options[:size]
        js_options['externalControl'] = "'#{options[:external_control]}'" if options[:external_control]
        js_options['loadTextURL'] = "'#{url_for(options[:load_text_url])}'" if options[:load_text_url]        
        js_options['ajaxOptions'] = options[:options] if options[:options]
        js_options['evalScripts'] = options[:script] if options[:script]
        js_options['callback']   = "function(form) { return #{options[:with]} }" if options[:with]
        js_options['clickToEditText'] = %('#{options[:click_to_edit_text]}') if options[:click_to_edit_text]
        function << (', ' + options_for_javascript(js_options)) unless js_options.empty?
        
        function << ')'

        javascript_tag(function)
      end
      
      # def active_scaffold_inplace_edit(record, column)
      #   formatted_column = format_inplace_edit_column(record,column)
      #   id_options = {:id => record.id.to_s, :action => 'update_column', :name => column.name.to_s}
      #   tag_options = {:tag => "span", :id => element_cell_id(id_options), :class => "in_place_editor_field"}
      #   in_place_editor_options = {:url => {:controller => params_for[:controller], :action => "update_column", :column => column.name, :id => record.id.to_s},
      #    :click_to_edit_text => as_("Click to edit"),
      #    :cancel_text => as_("Cancel"),
      #    :loading_text => as_("Loading…"),
      #    :save_text => as_("Update"),
      #    :saving_text => as_("Saving…"),
      #    :html_response => false,
      #    :options => "{method: 'post'}",
      #    :script => true}.merge(column.options)
      #   content_tag(:span, formatted_column, tag_options) + active_scaffold_in_place_editor_js(tag_options[:id], in_place_editor_options)
      # end

      # Allow in_place_editor to pass along nested information so the update_column can call refresh_record properly.
      def active_scaffold_inplace_edit(record, column, options = {})
        formatted_column = options[:formatted_column] || format_inplace_edit_column(record, column)
        id_options = {:id => record.id.to_s, :action => 'update_column', :name => column.name.to_s}
        tag_options = {:tag => "span", :id => element_cell_id(id_options), :class => "in_place_editor_field"}
        in_place_editor_options = {:url => {:controller => params_for[:controller], :action => "update_column", :eid => params[:eid], :parent_model => params[:parent_model], :column => column.name, :id => record.id.to_s},
         :click_to_edit_text => as_(:click_to_edit),
         :cancel_text => as_(:cancel),
         :loading_text => as_(:loading_),
         :save_text => as_(:update),
         :saving_text => as_(:saving_),
         :script => true}.merge(column.options)
        html =  html_for_inplace_display(formatted_column, tag_options[:id], in_place_editor_options)
        html << form_for_inplace_display(record, column, tag_options[:id], in_place_editor_options, options)
      end

      def check_for_choices(options)
        raise ArgumentError, "Missing choices for select! Specify options[:choices] for in_place_select" if options[:choices].nil?
      end
      
      def html_for_inplace_display(display_text, id_string, in_place_editor_options)
        content_tag(:span, display_text,
          :onclick => "Element.hide(this);$('#{id_string}_form').show();", 
          :onmouseover => visual_effect(:highlight, id_string), 
          :title => in_place_editor_options[:click_to_edit_text], 
          :id => id_string,
          :class => "inplace_span")
      end

      def form_for_inplace_display(record, column, id_string, in_place_editor_options, options)
        retval = ""
        in_place_editor_options[:url] ||= {}
        in_place_editor_options[:url][:action] ||= "set_record_#{column.name}"
        in_place_editor_options[:url][:id] ||= record.id
        loader_message = in_place_editor_options[:saving_text] || as_(:saving_)
        retval << form_remote_tag(:url => in_place_editor_options[:url],
  				:method => in_place_editor_options[:http_method] || :post,
          :loading => "$('#{id_string}_form').hide(); $('loader_#{id_string}').show();",
          :complete => "$('loader_#{id_string}').hide();",
          :html => {:class => "in_place_editor_form", :id => "#{id_string}_form", :style => "display:none" } )

        retval << field_for_inplace_editing(record, options, column )
        retval << content_tag(:br) if in_place_editor_options[:br]
        retval << submit_tag(as_(:ok), :class => "inplace_submit")
        retval << link_to_function( "Cancel", "$('#{id_string}_form').hide();$('#{id_string}').show() ", {:class => "inplace_cancel" })
        retval << "</form>"
        # #FIXME 2008-01-14 (EJM) Level=0 - Use AS's spinner
        # retval << invisible_loader( loader_message, "loader_#{id_string}", "inplace_loader")
        retval << content_tag(:br)
      end

      def field_for_inplace_editing(record, options, column)
        input_type = column.list_ui
        options[:class] = "inplace_#{input_type}"
        htm_opts = {:class => options[:class] }
        case input_type
        when :textarea
          text_area_tag('value', record.send(column.name), options )
        when :select
          select_tag('value', record.send(column.name), options[:choices], {:selected => record.send(column.name)}.merge(options), htm_opts )
        # when :date_select
        #   calendar_date_select( :record, column.name, options)
        else
          text_field_tag('value', record.send(column.name), options)
        end
      end
      
    end
  end
end