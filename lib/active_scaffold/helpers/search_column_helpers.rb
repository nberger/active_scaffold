module ActiveScaffold
  module Helpers
    # Helpers that assist with the rendering of a Form Column
    module SearchColumnHelpers
      # This method decides which input to use for the given column.
      # It does not do any rendering. It only decides which method is responsible for rendering.
=begin
      def active_scaffold_search_for(column)
        options = active_scaffold_search_options(column)

        # first, check if the dev has created an override for this specific field for search
        if override_search_field?(column)
          send(override_search_field(column), @record, options[:name])

        # first, check if the dev has created an override for this specific field
        elsif override_form_field?(column)
          send(override_form_field(column), @record, options[:name])

        # second, check if the dev has specified a valid search_ui for this column, using specific ui for searches
        elsif column.search_ui and override_search?(column.search_ui)
          send(override_search(column.search_ui), column, options)

        # third, check if the dev has specified a valid search_ui for this column, using generic ui for forms
        elsif column.search_ui and override_input?(column.search_ui)
          send(override_input(column.search_ui), column, options)

        # fallback: we get to make the decision
        else
          if column.association or column.virtual?
            active_scaffold_search_text(column, options)

          else # regular model attribute column
            # if we (or someone else) have created a custom render option for the column type, use that
            if override_search?(column.column.type)
              send(override_search(column.column.type), column, options)
            # if we (or someone else) have created a custom render option for the column type, use that
            elsif override_input?(column.column.type)
              send(override_input(column.column.type), column, options)
            # final ultimate fallback: use rails' generic input method
            else
              # for textual fields we pass different options
              text_types = [:text, :string, :integer, :float, :decimal]
              options = active_scaffold_input_text_options(options) if text_types.include?(column.column.type)
              input(:record, column.name, options.merge(column.options))
            end
          end
        end
      end
=end
      def active_scaffold_search_for(column)
        begin
          options = active_scaffold_search_options(column)
          restore_column_value_from_search_session(column)
          
          # first, check if the dev has created an override for this specific field
          if override_search_field?(column)
            send(override_search_field(column), @record, column, options)
          
          # second, check if the dev has specified a valid search_ui for this column, using specific ui for searches
          elsif column.search_ui and override_search?(column.search_ui)
            send(override_search(column.search_ui), column, options)

          # third, check if the dev has specified a valid search_ui for this column, using generic ui for forms
          elsif column.search_ui and override_input?(column.search_ui)
            send(override_input(column.search_ui), column, options)

          # fallback: we get to make the decision
          else
            if column.virtual?
              active_scaffold_search_text(column, options)
            
            elsif column.association
              active_scaffold_input_select(column, options)

            else # regular model attribute column
              # if we (or someone else) have created a custom render option for the column type, use that
              if override_search?(column.column.type)
                send(override_search(column.column.type), column, options)
              # if we (or someone else) have created a custom render option for the column type, use that
              elsif override_input?(column.column.type)
                send(override_input(column.column.type), column, options)
              # final ultimate fallback: use rails' generic input method
              else
                # for textual fields we pass different options
                text_types = [:text, :string, :integer, :float, :decimal]
                options = active_scaffold_input_text_options(options) if text_types.include?(column.column.type)
                input(:record, column.name, options.merge(column.options))
              end
            end
          end
        rescue Exception => e
          logger.error Time.now.to_s + "#{e.inspect} -- on the ActiveScaffold column = :#{column.name} in #{@controller.class}"
          raise e
        end        
      end

      # the standard active scaffold options used for class, name and scope
      def active_scaffold_search_options(column)
        { :name => "search[#{column.name}]", :class => "#{column.name}-input", :id => "search_#{column.name}"}
      end

      ##
      ## Search input methods
      ##

      def active_scaffold_search_multi_select(column, options)
		return active_scaffold_search_select(column, options.merge(:multiple => true), select_options)
        associated_options = @record.send(column.association.name).collect {|r| [r.to_label, r.id]}
        select_options = associated_options | options_for_association(column.association, true)
        return as_(:no_options) if select_options.empty?

        html = "<ul class=\"checkbox-list\" id=\"#{options[:id]}\">"

        associated_ids = associated_options.collect {|a| a[1]}
        select_options.each_with_index do |option, i|
          label, id = option
          this_name = "#{options[:name]}[#{i}][id]"
          this_id = "#{options[:id]}_#{i}_id"
          html << "<li>"
          html << check_box_tag(this_name, id, associated_ids.include?(id), :id => this_id)
          html << "<label for='#{this_id}'>"
          html << label
          html << "</label>"
          html << "</li>"
        end

        html << '</ul>'
        html << javascript_tag("new DraggableLists('#{options[:id]}')") if column.options[:draggable_lists]
        html
      end

      def active_scaffold_search_select(column, options, select_options = nil)
        selected_ids = search_session_column_multi_select_values(column)
        if column.association
          select_options ||= options_for_association(column.association, true)
          method = column.association.macro == :belongs_to ? column.association.primary_key_name : column.name
          options[:name] += options[:multiple] == true ? '[]' : '[id]'
          include_blank = options[:multiple] == true ? true : ''
          select(:record, method, select_options.uniq, {:selected => selected_ids, :include_blank => include_blank}, options)
        else
          options[:name] += '[]' if options[:multiple] == true
          select(:record, column.name, select_options, { :selected => selected_ids, :include_blank => true },  options)
        end
      end

      def active_scaffold_search_text(column, options)
        text_field :record, column.name, active_scaffold_input_text_options(options)
      end

      # we can't use active_scaffold_input_boolean because we need to have a nil value even when column can't be null
      # to decide whether search for this field or not
      def active_scaffold_search_boolean(column, options)
        select_options = []
        select_options << [as_(:nil), nil]
        select_options << [as_(:true), true]
        select_options << [as_(:false), false]

        value = @record.send(column.name)
        value = value.blank? ? nil : (value ? 1 : 0)
        select_tag(options[:name], options_for_select(select_options, value))
      end
      # we can't use checkbox ui because it's not possible to decide whether search for this field or not
      alias_method :active_scaffold_search_checkbox, :active_scaffold_search_boolean

      def active_scaffold_search_range(column, options)
        opt_value, from_value, to_value = search_session_column_range_values(column)
        html = []
        string_or_text = ([:string, :text].include?(column.column.type) || [:text].include?(column.search_ui))
        select_options = string_or_text ? ActiveScaffold::Finder::StringComparators : ActiveScaffold::Finder::NumericComparators
        html << select_tag("#{options[:name]}[opt]",
              options_for_select(select_options, opt_value),
              :id => "#{options[:id]}_opt",
              :onchange => "Element[this.value == 'BETWEEN' ? 'show' : 'hide']('#{options[:id]}_between');")
        html << text_field_tag("#{options[:name]}[from]", from_value, active_scaffold_input_text_options(:id => options[:id], :size => 10))
        html << content_tag(:span, ' - ' + text_field_tag("#{options[:name]}[to]", to_value,
              active_scaffold_input_text_options(:id => "#{options[:id]}_to", :size => 10)),
              :id => "#{options[:id]}_between", :style => to_value.blank? ? "display:none" : "")
        html * ' '
      end
      alias_method :active_scaffold_search_integer, :active_scaffold_search_range
      alias_method :active_scaffold_search_decimal, :active_scaffold_search_range
      alias_method :active_scaffold_search_float, :active_scaffold_search_range
      alias_method :active_scaffold_search_usa_money, :active_scaffold_search_range
      alias_method :active_scaffold_search_string, :active_scaffold_search_range
      alias_method :active_scaffold_search_text, :active_scaffold_search_range

      def active_scaffold_search_datetime(column, options)
        options = column.options.merge(options)
        helper = "select_#{'date' unless options[:discard_date]}#{'time' unless options[:discard_time]}"
        html = []
        html << send(helper, nil, {:include_blank => true, :prefix => "#{options[:name]}[from]"}.merge(options))
        html << send(helper, nil, {:include_blank => true, :prefix => "#{options[:name]}[to]"}.merge(options))
        html * ' - '
      end

      def active_scaffold_search_date(column, options)
        active_scaffold_search_datetime(column, options.merge!(:discard_time => true))
      end
      def active_scaffold_search_time(column, options)
        active_scaffold_search_datetime(column, options.merge!(:discard_date => true))
      end
      alias_method :active_scaffold_search_timestamp, :active_scaffold_search_datetime
      
      def active_scaffold_search_dhtml_calendar(column, options)
        opt_value, from_value, to_value = search_session_column_range_values(column)
        id_name = options[:id]
        html = []
        html << select_tag("#{options[:name]}[opt]",
              options_for_select(ActiveScaffold::Finder::NumericComparators, opt_value),
              :id => "#{id_name}_opt",
              :onchange => "Element[this.value == 'BETWEEN' ? 'show' : 'hide']('#{id_name}_between');")
        options = {:name => "#{options[:name]}[from]", :help_string => "", :class => "range-input"}.merge(active_scaffold_input_text_options(:id => "#{id_name}_from", :size => 10))
        options[:value] = nil
        options[:value] = from_value
        html << active_scaffold_input_calendar_date_select(column, options)
        options[:value] = nil
        options[:value] = to_value
        options[:name].gsub!('[from]', '[to]')
        options[:id].gsub!('_from', '_to')
        html << content_tag(:span, ' - ' + active_scaffold_input_calendar_date_select(column, options),
                          :id => "#{id_name}_between", :style => to_value.blank? ? "display:none" : "")
        html * ' '
      end
      alias_method :active_scaffold_search_calendar_date_select, :active_scaffold_search_dhtml_calendar

      def active_scaffold_search_usa_state(column, options)
        @record.send("#{column.name}=", search_session_column_multi_select_values(column))
        select_options = options
        select_options.delete(:size)
        options.delete([:prompt, :priority])
        usa_state_select(:record, column.name, column.options[:priority], select_options, column.options.merge!(options))
      end

      def active_scaffold_search_record_select(column, options)
        begin
          value = @search_session_info[column.name] unless @search_session_info.nil?
          if column.plural_association?
            value.collect! {|id|  Float(id) rescue nil ? id.to_i : id}.flatten if value
            @record.send("#{column.name}=", column.association.klass.find(value)) if value
          else
            if value.blank?
              value = nil
            else
              value = Float(value) rescue nil ? value.to_i : value
              value = column.association.klass.find(value)
            end
            @record.send("#{column.name}=", value)
          end
        rescue   Exception => e
          logger.error Time.now.to_s + "Sorry, we are not that smart yet. Attempted to restore search values to search fields but instead got -- #{e.inspect} -- on the ActiveScaffold column = :#{column.name} in #{@controller.class}"
          raise e
        end

        unless column.association
          raise ArgumentError, "record_select can only work against associations (and #{column.name} is not).  A common mistake is to specify the foreign key field (like :user_id), instead of the association (:user)."
        end
        remote_controller = File.join('/', active_scaffold_controller_for(column.association.klass).controller_path)

        # if the opposite association is a :belongs_to, then only show records that have not been associated yet
        params = {:parent_model => @record.class}

        record_select_options = {:controller => remote_controller, :id => options[:id], :params => params}
        record_select_options.merge!(active_scaffold_input_text_options)
        record_select_options.merge!(column.options)

        if column.singular_association?
          record_select_field(options[:name], (@record.send(column.name) || column.association.klass.new), record_select_options)
        elsif column.plural_association?
          record_multi_select_field(options[:name], @record.send(column.name), record_select_options)
        end   
      end
      
      def restore_column_value_from_search_session(column)
        begin
          search_ui = column.search_ui || column.column.type
          return if search_ui.nil?
          value = @search_session_info[column.name] unless @search_session_info.nil?
          # ActiveRecord is tooooo painful to make complex values work so we do it inside the html helper methods
          return if column.association or value.is_a?(Hash) or value.is_a?(Array)
          # To avoid column defaults in model we try to do an assignment to the column regardless
          @record.send("#{column.name}=", value)
        rescue   Exception => e
          logger.error Time.now.to_s + "Sorry, we are not that smart yet. Attempted to restore search values to search fields but instead got -- #{e.inspect} -- on the ActiveScaffold column = :#{column.name} in #{@controller.class}"
          # raise e
        end
      end

      def search_session_column_range_values(column)
        search_ui = column.search_ui || column.column.type
        return nil if @search_session_info.nil? or search_ui.nil?
        values = @search_session_info[column.name]
        return nil, nil, nil if values.blank?
        return values[:opt], values[:from], values[:to]
      end

      def search_session_column_multi_select_values(column)
        begin
          value = @search_session_info[column.name] unless @search_session_info.nil?
          if value.is_a?(Hash)
            value = Float(value[:id]) rescue nil ? value[:id].to_i : value[:id] if value.has_key?(:id)
          else
            value.collect! {|id|  Float(id) rescue nil ? id.to_i : id}.flatten if value
          end
          value
        rescue   Exception => e
          logger.error Time.now.to_s + "Sorry, we are not that smart yet. Attempted to restore search values to search fields but instead got -- #{e.inspect} -- on the ActiveScaffold column = :#{column.name} in #{@controller.class}"
          # raise e
        end
      end

      ##
      ## Search column override signatures
      ##

      def override_search?(search_ui)
        respond_to?(override_search(search_ui))
      end

      # the naming convention for overriding search input types with helpers
      def override_search(form_ui)
        "active_scaffold_search_#{form_ui}"
      end
      
      def override_search_field?(column)
        respond_to?(override_search_field(column))
      end

      # the naming convention for overriding form fields with helpers
      def override_search_field(column)
        "#{column.name}_search_column"
      end

      def active_scaffold_search_textarea(column, options)
        active_scaffold_search_text(column, options)
      end

    end
  end
end
