module ActiveScaffold::Actions
  module PrintBase
    include ActiveScaffold::Search
    protected
    
    def do_print_list(print_list_config)
      active_scaffold_config.list.empty_field_text = print_list_config.empty_field_text
      includes_for_print_list_columns = active_scaffold_tools_list_columns.collect{ |c| c.includes }.flatten.uniq.compact
      self.active_scaffold_joins.concat includes_for_print_list_columns

      options = {:sorting => active_scaffold_config.list.user.sorting,
        :per_page => print_list_config.maximum_rows}

      do_search
      
      do_print_list_find(options)
    end

    def do_print_list_find(options)
      @records = find_page(options);
    end
  end
end