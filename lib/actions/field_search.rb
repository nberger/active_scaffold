module ActiveScaffold::Actions
  module FieldSearch
    include ActiveScaffold::Search
    def self.included(base)
      base.before_filter :field_search_authorized?, :only => :show_search
      base.before_filter :reset_search_session_info
      base.before_filter :do_search
    end

    # FieldSearch uses params[:search] and not @record because search conditions do not always pass the Model's validations.
    # This facilitates for example, textual searches against associations via .search_sql
    def show_search
      do_show_search
      
      respond_to do |type|
        type.html { render(:action => "field_search") }
        type.js { render(:partial => "field_search", :layout => false) }
      end
    end

    def reset_search
      update_table      
    end
    
    protected

    def do_search
      store_params_into_search_session_info
      unless search_session_info.empty?
        like_pattern = active_scaffold_config.field_search.full_text_search? ? '%?%' : '?%'
        search_conditions = []
        search_session_info.each do |key, value|
          next unless active_scaffold_config.field_search.columns.include?(key)
          column = active_scaffold_config.columns[key]
          search_conditions << ActiveScaffold::Finder.condition_for_column(column, value, like_pattern)
        end
        search_conditions.compact!
        self.active_scaffold_conditions = merge_conditions(self.active_scaffold_conditions, *search_conditions)
        @filtered = !search_conditions.blank?

        columns = active_scaffold_config.field_search.columns
        includes_for_search_columns = columns.collect{ |column| column.includes}.flatten.uniq.compact
        self.active_scaffold_joins.concat includes_for_search_columns

        active_scaffold_config.list.user.page = nil
      end
    end

    def do_show_search
      @record = active_scaffold_config.model.new
      @search_session_info = search_session_info
    end
    
    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def field_search_authorized?
      authorized_for?(:action => :read)
    end
  end
end
