module ActiveScaffold::Actions
  module FieldSearch
    include ActiveScaffold::Search
    def self.included(base)
      base.before_filter :field_search_authorized_filter, :only => :show_search
      base.before_filter :do_search
    end

    # FieldSearch uses params[:search] and not @record because search conditions do not always pass the Model's validations.
    # This facilitates for example, textual searches against associations via .search_sql
    def show_search
      params[:search] ||= {}
      @record = active_scaffold_config.model.new
      respond_to_action(:field_search)
    end

    def reset_search
      reset_search_session_info
      update_table      
    end
    
    protected
    def field_search_respond_to_html
      render(:action => "field_search")
    end
    
    def field_search_respond_to_js
      render(:partial => "field_search")
    end

    def do_search
=begin
      unless params[:search].nil?
        like_pattern = active_scaffold_config.field_search.full_text_search? ? '%?%' : '?%'
        search_conditions = []
        columns = active_scaffold_config.field_search.columns
        columns.each do |column|
          search_conditions << self.class.condition_for_column(column, params[:search][column.name], like_pattern)
        end
        search_conditions.compact!
        self.active_scaffold_conditions = merge_conditions(self.active_scaffold_conditions, *search_conditions)
        @filtered = !search_conditions.blank?

        includes_for_search_columns = columns.collect{ |column| column.includes}.flatten.uniq.compact
        self.active_scaffold_joins.concat includes_for_search_columns

        active_scaffold_config.list.user.page = nil
      end
=end
      store_params_into_search_session_info
      unless search_session_info.empty?
        like_pattern = active_scaffold_config.field_search.full_text_search? ? '%?%' : '?%'
        search_conditions = []
        search_session_info.each do |key, value|
          next unless active_scaffold_config.field_search.columns.include?(key)
          column = active_scaffold_config.columns[key]
          search_conditions << self.class.condition_for_column(column, value, like_pattern)
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

    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def search_authorized?
      authorized_for?(:action => :read)
    end
    private
    def field_search_authorized_filter
      link = active_scaffold_config.field_search.link || active_scaffold_config.field_search.class.link
      raise ActiveScaffold::ActionNotAllowed unless self.send(link.security_method)
    end
    def field_search_formats
      (default_formats + active_scaffold_config.formats + active_scaffold_config.field_search.formats).uniq
    end
  end
end
