module ActiveScaffold
  module Finder
    module ClassMethods
      # Takes a collection of search terms (the tokens) and creates SQL that
      # searches all specified ActiveScaffold columns. A row will match if each
      # token is found in at least one of the columns.
      def create_conditions_for_columns(tokens, columns, like_pattern = '%?%')
        # if there aren't any columns, then just return a nil condition
        return unless columns.length > 0

        tokens = [tokens] if tokens.is_a? String

        where_clauses = []
        columns.each do |column|
          where_clauses << ((column.column.nil? || column.column.text?) ? "LOWER(#{column.search_sql}) LIKE ?" : "#{column.search_sql} = ?")
        end
        phrase = "(#{where_clauses.join(' OR ')})"

        sql = ([phrase] * tokens.length).join(' AND ')
        tokens = tokens.collect do |value|
          columns.collect {|column| (column.column.nil? || column.column.text?) ? like_pattern.sub('?', value.downcase) : column.column.type_cast(value)}
        end.flatten

        [sql, *tokens]
      end

      # Generates an SQL condition for the given ActiveScaffold column based on
      # that column's database type (or form_ui ... for virtual columns?).
      # TODO: this should reside on the column, not the controller
      def condition_for_column(column, value, like_pattern = '%?%')
        # we must check false or not blank because we want to search for false but false is blank
        return unless column and column.search_sql and not value.blank?
        # AST Begin - TODO - ist this still needed?
        return if (value.is_a?(Array) and value.join.blank?)
        # AST End
        search_ui = column.search_ui || column.column.type
        if self.respond_to?("condition_for_#{column.name}_column")
          self.send("condition_for_#{column.name}_column", column, value, like_pattern)
        elsif self.respond_to?("condition_for_#{search_ui}_type")
          self.send("condition_for_#{search_ui}_type", column, value, like_pattern)
        else
          case search_ui
            when :boolean, :checkbox
            ["#{column.search_sql} = ?", column.column.type_cast(value)]
            when :select
            ["#{column.search_sql} = ?", value[:id]] unless value[:id].blank?
            when :multi_select
            ["#{column.search_sql} in (?)", value.values.collect{|hash| hash[:id]}]
            else
              if column.column.nil? || column.column.text?
                ["LOWER(#{column.search_sql}) LIKE ?", like_pattern.sub('?', value.downcase)]
              else
                ["#{column.search_sql} = ?", column.column.type_cast(value)]
              end
          end
        end
      end

      # AST why require like_pattern
      def condition_for_integer_type(column, value, like_pattern = nil)
        if value['from'].blank? or not ActiveScaffold::Finder::NumericComparators.include?(value['opt'])
          nil
        elsif value['opt'] == 'BETWEEN'
          ["#{column.search_sql} BETWEEN ? AND ?", value['from'].to_f, value['to'].to_f]
        else
          ["#{column.search_sql} #{value['opt']} ?", value['from'].to_f]
        end
      end
      alias_method :condition_for_decimal_type, :condition_for_integer_type
      alias_method :condition_for_float_type, :condition_for_integer_type
      # AST condition_for_usa_money_type
      alias_method :condition_for_usa_money_type, :condition_for_integer_type

      # AST condition_for_string_type
      def condition_for_string_type(column, value, like_pattern = '%?%')
        if !value.is_a?(Hash)
          ["LOWER(#{column.search_sql}) LIKE ?", like_pattern.sub('?', value.downcase)]
        elsif value['from'].blank? or not ActiveScaffold::Finder::StringComparators.flatten.include?(value['opt'])
          nil
        elsif value['opt'] == 'BETWEEN'
          ["#{column.search_sql} BETWEEN ? AND ?", value['from'], value['to']]
        elsif value['opt'].include?('?')
          ["#{column.search_sql} LIKE ?", value['opt'].sub('?', value['from'].downcase)]
        else
          ["#{column.search_sql} #{value['opt']} ?", value['from']]
        end
      end
      alias_method :condition_for_email_type, :condition_for_string_type
      alias_method :condition_for_text_type, :condition_for_string_type

      # AST why require like_pattern
      def condition_for_datetime_type(column, value, like_pattern = nil)
        conversion = value['from']['hour'].blank? && value['to']['hour'].blank? ? 'to_date' : 'to_time'
        from_value, to_value = ['from', 'to'].collect do |field|
          Time.zone.local(*['year', 'month', 'day', 'hour', 'minutes', 'seconds'].collect {|part| value[field][part].to_i}) rescue nil
        end

        if from_value.nil? and to_value.nil?
          nil
        elsif !from_value
          ["#{column.search_sql} <= ?", to_value.send(conversion).to_s(:db)]
        elsif !to_value
          ["#{column.search_sql} >= ?", from_value.send(conversion).to_s(:db)]
        else
          ["#{column.search_sql} BETWEEN ? AND ?", from_value.send(conversion).to_s(:db), to_value.send(conversion).to_s(:db)]
        end
      end
      alias_method :condition_for_date_type, :condition_for_datetime_type
      alias_method :condition_for_time_type, :condition_for_datetime_type
      alias_method :condition_for_timestamp_type, :condition_for_datetime_type

      # AST Begin
      def condition_for_dhtml_calendar_type(column, value, like_pattern = nil)
        return nil if value['from'].blank? or not ActiveScaffold::Finder::NumericComparators.include?(value['opt'])
        if value['opt'] == 'BETWEEN'
          ["#{column.search_sql} BETWEEN ? AND ?", value[:from], value[:to]]
        else
          ["#{column.search_sql} #{value['opt']} ?", value[:from]]
        end
      end
      alias_method :condition_for_calendar_date_select_type, :condition_for_dhtml_calendar_type

      def condition_for_exact_type(column, value, like_pattern = nil)
        ["#{column.search_sql} = ?", value]
      end

      def condition_for_record_select_type(column, value, like_pattern = nil)
        if value.is_a?(Array)
          ["#{column.search_sql} IN (?)", value]
        else
          ["#{column.search_sql} = ?", value]
        end
      end

      def condition_for_multi_select_type(column, value, like_pattern = nil)
        case value
        when Hash
          values = value.values
        else
          values = value
        end
        ["#{column.search_sql} in (?)", values]
      end
      alias_method :condition_for_usa_state_type, :condition_for_multi_select_type
      # AST End
    end

    NumericComparators = [
      '=',
      '>=',
      '<=',
      '>',
      '<',
      '!=',
      'BETWEEN'
    ]
    
    # AST StringComparators
    StringComparators = [
      ['is_like', '%?%'],
      ['begins_with', '?%'],
      ['ends_with', '%?'],
      ['=', '='],
      ['!=', '!='],
      ['BETWEEN', 'BETWEEN']
    ]

    def self.included(klass)
      klass.extend ClassMethods
    end

    protected

    attr_writer :active_scaffold_conditions
    def active_scaffold_conditions
      @active_scaffold_conditions ||= []
    end

    attr_writer :active_scaffold_joins
    def active_scaffold_joins
      @active_scaffold_joins ||= []
    end

    attr_writer :active_scaffold_habtm_joins
    def active_scaffold_habtm_joins
      @active_scaffold_habtm_joins ||= []
    end
    
    def all_conditions
      merge_conditions(
        active_scaffold_conditions,                   # from the search modules
        conditions_for_collection,                    # from the dev
        conditions_from_params,                       # from the parameters (e.g. /users/list?first_name=Fred)
        conditions_from_constraints,                  # from any constraints (embedded scaffolds)
        active_scaffold_session_storage[:conditions] # embedding conditions (weaker constraints)
      )
    end
    
    def model_with_named_scope(model = active_scaffold_config.model, scope_definitions = named_scopes_for_collection)
      case scope_definitions
      when String
        model.instance_eval(scope_definitions)
      when Symbol
        model.send(scope_definitions)
      when Array
        if scope_definitions.any?{|element| element.is_a?(Array)}
          scope_definitions.inject(model) {|records, scope_definition| records = model_with_named_scope(records, scope_definition)}
        else
          model.send(*scope_definitions)
        end
      else
        model
      end
    end
    
    # returns a single record (the given id) but only if it's allowed for the specified action.
    # accomplishes this by checking model.#{action}_authorized?
    # TODO: this should reside on the model, not the controller
    def find_if_allowed(id, action, klass = nil)
      klass ||= active_scaffold_config.model
      record = klass.find(id)
      # AST - add some additional info
      raise ActiveScaffold::RecordNotAllowed, "#{klass} with id = #{id}" unless record.authorized_for?(:action => action.to_sym)
      return record
    end

    # returns a Paginator::Page (not from ActiveRecord::Paginator) for the given parameters
    # options may include:
    # * :sorting - a Sorting DataStructure (basically an array of hashes of field => direction, e.g. [{:field1 => 'asc'}, {:field2 => 'desc'}]). please note that multi-column sorting has some limitations: if any column in a multi-field sort uses method-based sorting, it will be ignored. method sorting only works for single-column sorting.
    # * :per_page
    # * :page
    # TODO: this should reside on the model, not the controller
    def find_page(options = {})
      options.assert_valid_keys :sorting, :per_page, :page, :count_includes

      full_includes = (active_scaffold_joins.blank? ? nil : active_scaffold_joins)
      search_conditions = all_conditions
      options[:per_page] ||= 999999999
      options[:page] ||= 1
      options[:count_includes] ||= full_includes unless search_conditions.nil?

      klass = model_with_named_scope
      
      # create a general-use options array that's compatible with Rails finders
      finder_options = { :order => options[:sorting].try(:clause),
                         :conditions => search_conditions,
                         :joins => joins_for_finder,
                         :include => options[:count_includes]}
                         
      finder_options.merge! custom_finder_options

      # NOTE: we must use :include in the count query, because some conditions may reference other tables
      count = klass.count(finder_options.reject{|k,v| [:select, :order].include? k})

      # Converts count to an integer if ActiveRecord returned an OrderedHash
      # that happens when finder_options contains a :group key
      count = count.length if count.is_a? ActiveSupport::OrderedHash

      finder_options.merge! :include => full_includes

      # we build the paginator differently for method- and sql-based sorting
      if options[:sorting] and options[:sorting].sorts_by_method?
        pager = ::Paginator.new(count, options[:per_page]) do |offset, per_page|
          sorted_collection = sort_collection_by_column(klass.all(finder_options), *options[:sorting].first)
          sorted_collection.slice(offset, per_page)
        end
      else
        pager = ::Paginator.new(count, options[:per_page]) do |offset, per_page|
          klass.all(finder_options.merge(:offset => offset, :limit => per_page))
        end
      end

      pager.page(options[:page])
    end

    def joins_for_finder
      case joins_for_collection
        when String
          [ joins_for_collection ]
        when Array
          joins_for_collection
        else
          []
      end + active_scaffold_habtm_joins
    end

    # AST find_page_by_sql
    def find_page_by_sql(options = {}, sql_options = {})
      options.assert_valid_keys :sorting, :per_page, :page
      sql_options.assert_valid_keys :select, :from, :where, :group_by, :order_by
        options[:per_page] ||= 999999999
      options[:page] ||= 1

      klass = active_scaffold_config.model

      if active_scaffold_conditions.length > 0
        sql_options[:where] << " AND " if sql_options[:where]
        sql_options[:where] ||= " Where "
        sql_options[:where] << active_scaffold_conditions
      end
      count_clause = "Select count(*) #{sql_options[:from]} #{sql_options[:where]}"
      count_clause = "Select count(*) From (Select count(*) #{sql_options[:from]} #{sql_options[:where]} #{sql_options[:group_by]}) as T" if sql_options[:group_by]
      count = klass.count_by_sql(count_clause)

      # we build the paginator differently for method- and sql-based sorting
      if options[:sorting] and options[:sorting].sorts_by_method?
        pager = ::Paginator.new(count, options[:per_page]) do |offset, per_page|
          sorted_collection = sort_collection_by_column(klass.find_by_sql("#{sql_options[:select]} #{sql_options[:from]} #{sql_options[:where]} #{sql_options[:group_by]} #{sql_options[:order_by]}"), *options[:sorting].first)
          sorted_collection.slice(offset, per_page)
        end
      else
        pager = ::Paginator.new(count, options[:per_page]) do |offset, per_page|
          klass.find_by_sql("#{sql_options[:select]} #{sql_options[:from]} #{sql_options[:where]} #{sql_options[:group_by]} #{sql_options[:order_by]} Limit #{offset}, #{per_page}")
        end
      end

      page = pager.page(options[:page])
    end
  
    def merge_conditions(*conditions)
      active_scaffold_config.model.merge_conditions(*conditions)
    end

    # TODO: this should reside on the column, not the controller
    def sort_collection_by_column(collection, column, order)
      sorter = column.sort[:method]
      collection = collection.sort_by { |record|
        value = (sorter.is_a? Proc) ? record.instance_eval(&sorter) : record.instance_eval(sorter)
        value = '' if value.nil?
        value
      }
      collection.reverse! if order.downcase == 'desc'
      collection
    end
  end
end
