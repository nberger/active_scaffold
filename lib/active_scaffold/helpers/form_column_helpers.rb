module ActiveScaffold
  module Helpers
    # Helpers that assist with the rendering of a Form Column
    module FormColumnHelpers
      
      # This method decides which input to use for the given column.
      # It does not do any rendering. It only decides which method is responsible for rendering.
      def active_scaffold_input_for(column, scope = nil, options = {})
        begin
          options = active_scaffold_input_options(column, scope, options)

          # first, check if the dev has created an override for this specific field
          if override_form_field?(column)
            send(override_form_field(column), @record, column, options)

          # second, check if the dev has specified a valid form_ui for this column
          elsif column.form_ui and override_input?(column.form_ui)
            html = send(override_input(column.form_ui), column, options)
            html << active_scaffold_observe(column, options[:id])
            html
          # fallback: we get to make the decision
          else
            if column.association
              # if we get here, it's because the column has a form_ui but not one ActiveScaffold knows about.
              raise "Unknown form_ui `#{column.form_ui}' for column `#{column.name}'"
            elsif column.virtual?
              html = active_scaffold_input_virtual(column, options)

            else # regular model attribute column
              # if we (or someone else) have created a custom render option for the column type, use that
              if override_input?(column.column.type)
                html = send(override_input(column.column.type), column, options)
              # final ultimate fallback: use rails' generic input method
              else
                # for textual fields we pass different options
                text_types = [:text, :string, :integer, :float, :decimal]
                options = active_scaffold_input_text_options(options) if text_types.include?(column.column.type)
                html = input(:record, column.name, options.merge(column.options))
              end
            end
            html << active_scaffold_observe(column, options[:id])
            html
          end
        rescue Exception => e
          logger.error Time.now.to_s + "#{e.inspect} -- on the ActiveScaffold column = :#{column.name} in #{@controller.class}"
          raise e
        end
      end

      alias form_column active_scaffold_input_for

      def active_scaffold_observe(column, id_name)
        if column.options[:observe_method]
          action = @record.id ? :update : :create
          return observe_field(id_name,
                      :frequency => 0.2,
                      :url => {:action => column.options[:observe_method], :parent_id => @record.id}, 
                      :with => "Form.serialize('#{element_form_id(:action => action)}')+'&='" ) unless !column.options[:observe_restrict_actions].nil? and column.options[:observe_restrict_actions].include?(action)
        end
        ''
      end

      # the standard active scaffold options used for textual inputs
      def active_scaffold_input_text_options(options = {})
        options[:autocomplete] = 'off'
        options[:size] ||= 20
        options[:class] = "#{options[:class]} text-input".strip
        options
      end

      # the standard active scaffold options used for class, name and scope
      def active_scaffold_input_options(column, scope = nil, options = {})
        if active_scaffold_config.upper_case_form_fields and column.column and [:text, :string].include?(column.column.type) and column.form_ui.nil? and (!column.options.has_key?(:upper_case_form_fields) or column.options[:upper_case_form_fields] != false)
          options[:onchange] ||= ''
          options.merge!(:onchange => options[:onchange] + "ToUpper(this);") 
        end
        options[:class] ||= "#{column.name}-input"
        name = scope ? "record#{scope}[#{column.name}]" : "record[#{column.name}]"
        { :name => name, :id => "record_#{column.name}_#{[params[:eid], params[:id]].compact.join '_'}"}.merge(options)
      end

      ##
      ## Form input methods
      ##

      def active_scaffold_add_existing_input(options)
        if controller.respond_to?(:record_select_config)
          remote_controller = active_scaffold_controller_for(record_select_config.model).controller_path
          record_select_field(
            "#{options[:name]}",
            active_scaffold_config.model.new,
            {:controller => remote_controller, :params => options[:url_options].merge(:parent_model => record_select_config.model)}.merge(active_scaffold_input_text_options))
        else
          # select_options = options_for_select(options_for_association(nested_association)) unless column.through_association?
          select_options ||= options_for_select(active_scaffold_config.model.find(:all).collect {|c| [h(c.to_label), c.id]})
          unless select_options.empty?
            select_tag 'associated_id', '<option value="">' + as_('- select -') + '</option>' + select_options
          end  
        end
      end

      def active_scaffold_add_existing_label
        if controller.respond_to?(:record_select_config)
          record_select_config.model.to_s.underscore.humanize
        else
          active_scaffold_config.model.to_s.underscore.humanize
        end
      end

      def active_scaffold_input_singular_association(column, options)
        associated = @record.send(column.association.name)

        select_options = options_for_association(column.association)
        select_options.unshift([ associated.to_label, associated.id ]) unless associated.nil? or select_options.find {|label, id| id == associated.id}

        selected = associated.nil? ? nil : associated.id
        method = column.association.macro == :belongs_to ? column.association.primary_key_name : column.name
        options[:name] += '[id]'
        select(:record, method, select_options.uniq, {:selected => selected, :include_blank => as_('- select -')}, options)
      end

      def active_scaffold_input_plural_association(column, options)
        associated_options = @record.send(column.association.name).collect {|r| [r.to_label, r.id]}
        select_options = associated_options | options_for_association(column.association)
        return 'no options' if select_options.empty?

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

      def active_scaffold_input_select(column, options)
        if column.singular_association?
          active_scaffold_input_singular_association(column, options)
        elsif column.plural_association?
          active_scaffold_input_plural_association(column, options)
        else
          select(:record, column.name, column.options, { :selected => @record.send(column.name) }, options)
        end
      end

      # only works for singular associations
      # requires RecordSelect plugin to be installed and configured.
      # ... maybe this should be provided in a bridge?
      def active_scaffold_input_record_select(column, options)
        unless column.association
          raise ArgumentError, "record_select can only work against associations (and #{column.name} is not).  A common mistake is to specify the foreign key field (like :user_id), instead of the association (:user)."
        end
        remote_controller = active_scaffold_controller_for(column.association.klass).controller_path

        # if the opposite association is a :belongs_to, then only show records that have not been associated yet
        params = {:parent_id => @record.id, :parent_model => @record.class}
        
        # if the opposite association is a :belongs_to, then only show records that have not been associated yet
        # robd 2008-06-29: is this code doing the right thing? doesn't seem to check :belongs_to...
        # in any case, could we encapsulate this code on column in a method like .singular_association?
        if [:has_one, :has_many].include?(column.association.macro)
          params.merge!({column.association.primary_key_name => ''})
        end
        
        record_select_options = {:controller => remote_controller, :id => options[:id], :params => params}
        record_select_options.merge!(active_scaffold_input_text_options)
        record_select_options.merge!(column.options)

        if column.singular_association?
          record_select_field(options[:name], (@record.send(column.name) || column.association.klass.new), record_select_options)
        elsif column.plural_association?
          record_multi_select_field(options[:name], @record.send(column.name), record_select_options)
        end   
      end

      def active_scaffold_input_checkbox(column, options)
        check_box(:record, column.name, options)
      end

      def active_scaffold_input_country(column, options)
        priority = ["United States"]
        select_options = {:prompt => as_('- select -')}
        select_options.merge!(options)
        country_select(:record, column.name, column.options[:priority] || priority, select_options, column.options)
      end

      def active_scaffold_input_password(column, options)
        password_field :record, column.name, active_scaffold_input_text_options(options)
      end

      def active_scaffold_input_textarea(column, options)
        text_area(:record, column.name, options.merge(:cols => column.options[:cols], :rows => column.options[:rows]))
      end

      def active_scaffold_input_usa_state(column, options)
        select_options = {:prompt => as_('- select -')}
        select_options.merge!(options)
        select_options.delete(:size)
        options.delete(:prompt)
        options.delete(:priority)
        usa_state_select(:record, column.name, column.options[:priority], select_options, column.options.merge!(options))
      end

      def active_scaffold_input_virtual(column, options)
        text_field :record, column.name, active_scaffold_input_text_options(options)
      end

      #
      # Column.type-based inputs
      #

      def active_scaffold_input_boolean(column, options)
        select_options = []
        select_options << [as_('- select -'), nil] if column.column.null
        select_options << [as_('True'), true]
        select_options << [as_('False'), false]

        select_tag(options[:name], options_for_select(select_options, @record.send(column.name)))
      end

      def onsubmit
      end

      ##
      ## Form column override signatures
      ##

      # add functionality for overriding subform partials from association class path
      def override_subform_partial?(column)
        path, partial_name = partial_pieces(override_subform_partial(column))
        template_exists?(File.join(path, "_#{partial_name}"))
      end

      def override_subform_partial(column)
        File.join(active_scaffold_controller_for(column.association.klass).controller_path, "subform") if column_renders_as(column) == :subform
      end

      def override_form_field_partial?(column)
        path, partial_name = partial_pieces(override_form_field_partial(column))
        template_exists?(File.join(path, "_#{partial_name}"))
      end

      # the naming convention for overriding form fields with partials
      def override_form_field_partial(column)
        "#{column.name}_form_column"
      end

      def override_form_field?(column)
        respond_to?(override_form_field(column))
      end

      # the naming convention for overriding form fields with helpers
      def override_form_field(column)
        "#{column.name}_form_column"
      end

      def override_input?(form_ui)
        respond_to?(override_input(form_ui))
      end

      # the naming convention for overriding form input types with helpers
      def override_input(form_ui)
        "active_scaffold_input_#{form_ui}"
      end

      def form_partial_for_column(column)
        if override_form_field_partial?(column)
          override_form_field_partial(column)
        elsif column_renders_as(column) == :field or override_form_field?(column)
          "form_attribute"
        elsif column_renders_as(column) == :subform
          "form_association"
        elsif column_renders_as(column) == :hidden
          "form_hidden_attribute"
        end
      end

      def subform_partial_for_column(column)
        if override_subform_partial?(column)
          override_subform_partial(column)
        else
          "horizontal_subform"
        end
      end

      ##
      ## Macro-level rendering decisions for columns
      ##

      def column_renders_as(column)
        if column.is_a? ActiveScaffold::DataStructures::ActionColumns
          return :subsection
        elsif column.active_record_class.locking_column.to_s == column.name.to_s
          return :hidden
        elsif column.association.nil? or column.form_ui or !active_scaffold_config_for(column.association.klass).actions.include?(:subform)
          return :field
        else
          return :subform
        end
      end

      def is_subsection?(column)
        column_renders_as(column) == :subsection
      end

      def is_subform?(column)
        column_renders_as(column) == :subform
      end
      
      def column_scope(column)
        if column.plural_association?
          "[#{column.name}][#{@record.id || generate_temporary_id}]"
        else
          "[#{column.name}]"
        end
      end
      
      # =======
      # = AST =
      # =======
      
      def active_scaffold_input_hidden(column, options)
    		input(:record, column.name, options.merge(:type => :hidden))
      end

      def active_scaffold_input_ssn(column, options)
        column.description ||= as_("Ex. 555-22-3333")
        options = active_scaffold_input_text_options(options)
    		text_field :record, column.name, options.merge(
                      :value => usa_number_to_ssn(@record[column.name].to_s),
                      :onblur => "SsnDashAdd(this);return true;")
      end
      
      def active_scaffold_input_timezone(column, options)
        time_zone_select(:record, column.name)
      end

      def active_scaffold_input_percentage(column, options)
        column.description ||= as_("Ex. 10%")
        options[:onblur] ||= "PercentageFormat(this);return true;"
        options = active_scaffold_input_text_options(options)
    		text_field :record, column.name, options.merge(:value => number_to_percentage(@record[column.name].to_s, :precision => 1))
      end

      # :usa_money requires some type casting help like the following in your Model
      #
      # def write_attribute(attr, value)
      #   if column_for_attribute(attr).precision
      #    value = BigDecimal(value.gsub(",", "").gsub("$", "")) if value.is_a?(String)
      #   end
      #   super
      # end
      def active_scaffold_input_usa_money(column, options)
        column.description ||= as_("Ex. 1,333")
        options[:onblur] ||= "UsaMoney(this);return true;"
        value = number_to_currency(@record[column.name].to_s) unless options[:blank_if_nil] == true
        value ||= "" 
        options = active_scaffold_input_text_options(options)
    		text_field :record, column.name, options.merge(:value => value)
      end

      def active_scaffold_input_usa_phone(column, options)
        column.description ||= as_("Ex. 111-333-4444")
        options[:onblur] ||= "UsaPhoneDashAdd(this);return true;"
        options = active_scaffold_input_text_options(options)
    		text_field :record, column.name, options.merge(:value => usa_number_to_phone(@record[column.name].to_s))
      end

      def active_scaffold_input_usa_zip(column, options)
        column.description ||= as_("Ex. 88888-3333")
        options[:onblur] ||= "UsaZipDashAdd(this);return true;"
        options = active_scaffold_input_text_options(options)
    		text_field :record, column.name, options.merge(:value => usa_number_to_zip(@record[column.name].to_s))
      end

      def active_scaffold_input_yes_no_radio(column, options)
        render :partial => '/yes_no_radio', :locals => {:column_name => column.name, :options => options}
      end

      def active_scaffold_input_true_false_radio(column, options)
        render :partial => '/true_false_radio', :locals => {:column_name => column.name, :options => options, :question_text => column.description, :question_type => :yes_or_no}
      end

      def remote_image_submit_tag(source, options)
        options[:with] ||= 'Form.serialize(this.form)'

        options[:html] ||= {}
        options[:html][:type] = 'image'
        options[:html][:onclick] = "#{remote_function(options)}; return false;"
        options[:html][:src] = image_path(source)

        tag("input", options[:html], false)
      end      

      # Return select and option tags for the given object and method, using country_options_for_select to generate the list of option tags.
      def country_select(object, method, priority_countries = nil, options = {}, html_options = {})
        ActionView::Helpers::InstanceTag.new(object, method, self, options.delete(:object)).to_country_select_tag(priority_countries, options, html_options)
      end

      def usa_state_select(object, method, priority_states = nil, options = {}, html_options = {})
        ActionView::Helpers::InstanceTag.new(object, method, self, options.delete(:object)).to_usa_state_select_tag(priority_states, options, html_options)
      end

      # Returns a string of option tags for pretty much any country in the world. Supply a country name as +selected+ to
      # have it marked as the selected option tag. You can also supply an array of countries as +priority_countries+, so
      # that they will be listed above the rest of the (long) list.
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in a regular HTML select tag.
      def country_options_for_select(selected = nil, priority_countries = nil)
        country_options = ""

        if priority_countries
          country_options += options_for_select(priority_countries, selected)
          country_options += "<option value=\"\" disabled=\"disabled\">-------------</option>\n"
        end

        return country_options + options_for_select(COUNTRIES, selected)
      end

      # Returns a string of option tags for the states in the United States. Supply a state name as +selected to
      # have it marked as the selected option tag. Included also is the option to set a couple of +priority_states+ 
      # in case you want to highligh a local area
      # NOTE: Only the option tags are returned from this method, wrap it in a <select>
      def usa_state_options_for_select(selected = nil, priority_states = nil)
        state_options = ""
        if priority_states
          state_options += options_for_select(priority_states, selected)
          state_options += "<option>-------------</option>\n"
        end

        if priority_states && priority_states.include?(selected)
          state_options += options_for_select(USASTATES - priority_states, selected)
        else
          state_options += options_for_select(USASTATES, selected)
        end

        return state_options
      end

      # All the countries included in the country_options output.
      COUNTRIES = ["Afghanistan", "Aland Islands", "Albania", "Algeria", "American Samoa", "Andorra", "Angola",
        "Anguilla", "Antarctica", "Antigua And Barbuda", "Argentina", "Armenia", "Aruba", "Australia", "Austria",
        "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin",
        "Bermuda", "Bhutan", "Bolivia", "Bosnia and Herzegowina", "Botswana", "Bouvet Island", "Brazil",
        "British Indian Ocean Territory", "Brunei Darussalam", "Bulgaria", "Burkina Faso", "Burundi", "Cambodia",
        "Cameroon", "Canada", "Cape Verde", "Cayman Islands", "Central African Republic", "Chad", "Chile", "China",
        "Christmas Island", "Cocos (Keeling) Islands", "Colombia", "Comoros", "Congo",
        "Congo, the Democratic Republic of the", "Cook Islands", "Costa Rica", "Cote d'Ivoire", "Croatia", "Cuba",
        "Cyprus", "Czech Republic", "Denmark", "Djibouti", "Dominica", "Dominican Republic", "Ecuador", "Egypt",
        "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Ethiopia", "Falkland Islands (Malvinas)",
        "Faroe Islands", "Fiji", "Finland", "France", "French Guiana", "French Polynesia",
        "French Southern Territories", "Gabon", "Gambia", "Georgia", "Germany", "Ghana", "Gibraltar", "Greece", "Greenland", "Grenada", "Guadeloupe", "Guam", "Guatemala", "Guernsey", "Guinea",
        "Guinea-Bissau", "Guyana", "Haiti", "Heard and McDonald Islands", "Holy See (Vatican City State)",
        "Honduras", "Hong Kong", "Hungary", "Iceland", "India", "Indonesia", "Iran, Islamic Republic of", "Iraq",
        "Ireland", "Isle of Man", "Israel", "Italy", "Jamaica", "Japan", "Jersey", "Jordan", "Kazakhstan", "Kenya",
        "Kiribati", "Korea, Democratic People's Republic of", "Korea, Republic of", "Kuwait", "Kyrgyzstan",
        "Lao People's Democratic Republic", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libyan Arab Jamahiriya",
        "Liechtenstein", "Lithuania", "Luxembourg", "Macao", "Macedonia, The Former Yugoslav Republic Of",
        "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Marshall Islands", "Martinique",
        "Mauritania", "Mauritius", "Mayotte", "Mexico", "Micronesia, Federated States of", "Moldova, Republic of",
        "Monaco", "Mongolia", "Montenegro", "Montserrat", "Morocco", "Mozambique", "Myanmar", "Namibia", "Nauru",
        "Nepal", "Netherlands", "Netherlands Antilles", "New Caledonia", "New Zealand", "Nicaragua", "Niger",
        "Nigeria", "Niue", "Norfolk Island", "Northern Mariana Islands", "Norway", "Oman", "Pakistan", "Palau",
        "Palestinian Territory, Occupied", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines",
        "Pitcairn", "Poland", "Portugal", "Puerto Rico", "Qatar", "Reunion", "Romania", "Russian Federation",
        "Rwanda", "Saint Barthelemy", "Saint Helena", "Saint Kitts and Nevis", "Saint Lucia",
        "Saint Pierre and Miquelon", "Saint Vincent and the Grenadines", "Samoa", "San Marino",
        "Sao Tome and Principe", "Saudi Arabia", "Senegal", "Serbia", "Seychelles", "Sierra Leone", "Singapore",
        "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa",
        "South Georgia and the South Sandwich Islands", "Spain", "Sri Lanka", "Sudan", "Suriname",
        "Svalbard and Jan Mayen", "Swaziland", "Sweden", "Switzerland", "Syrian Arab Republic",
        "Taiwan, Province of China", "Tajikistan", "Tanzania, United Republic of", "Thailand", "Timor-Leste",
        "Togo", "Tokelau", "Tonga", "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan",
        "Turks and Caicos Islands", "Tuvalu", "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom",
        "United States", "United States Minor Outlying Islands", "Uruguay", "Uzbekistan", "Vanuatu", "Venezuela",
        "Viet Nam", "Virgin Islands, British", "Virgin Islands, U.S.", "Wallis and Futuna", "Western Sahara",
        "Yemen", "Zambia", "Zimbabwe"] unless const_defined?("COUNTRIES")


    	USASTATES = [["Alabama", "AL"], ["Alaska", "AK"], ["Arizona", "AZ"], ["Arkansas", "AR"], ["California", "CA"], ["Colorado", "CO"], ["Connecticut", "CT"], ["Delaware", "DE"], ["District of Columbia", "DC"], ["Florida", "FL"], ["Georgia", "GA"], ["Hawaii", "HI"], ["Idaho", "ID"], ["Illinois", "IL"], ["Indiana", "IN"], ["Iowa", "IA"], ["Kansas", "KS"], ["Kentucky", "KY"], ["Louisiana", "LA"], ["Maine", "ME"], ["Maryland", "MD"], ["Massachusetts", "MA"], ["Michigan", "MI"], ["Minnesota", "MN"], ["Mississippi", "MS"], ["Missouri", "MO"], ["Montana", "MT"], ["Nebraska", "NE"], ["Nevada", "NV"], ["New Hampshire", "NH"], ["New Jersey", "NJ"], ["New Mexico", "NM"], ["New York", "NY"], ["North Carolina", "NC"], ["North Dakota", "ND"], ["Ohio", "OH"], ["Oklahoma", "OK"], ["Oregon", "OR"], ["Pennsylvania", "PA"], ["Rhode Island", "RI"], ["South Carolina", "SC"], ["South Dakota", "SD"], ["Tennessee", "TN"], ["Texas", "TX"], ["Utah", "UT"], ["Vermont", "VT"], ["Virginia", "VA"], ["Washington", "WA"], ["Wisconsin", "WI"], ["West Virginia", "WV"], ["Wyoming", "WY"]] unless const_defined?("USASTATES")

    class ActionView::Helpers::InstanceTag #:nodoc:
      include FormColumnHelpers

      def to_country_select_tag(priority_countries, options, html_options)
        ActiveSupport::Deprecation.warn("country_select will be removed from 2.2.0.  http://www.rubyonrails.org/deprecation/list-of-countries has more information.", caller)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        content_tag("select",
          add_options(
            country_options_for_select(value, priority_countries),
            options, value
          ), html_options
        )
      end

      def to_usa_state_select_tag(priority_states, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object) if method(:value).arity > 0
        if html_options[:name.to_s].include?('search')
          html_options[:name.to_s] << '[]' 
          html_options[:multiple] = true
          options[:include_blank] = true
        end
        content_tag("select", add_options(usa_state_options_for_select(value, priority_states), options, value), html_options)
      end
    end

    end
  end
end