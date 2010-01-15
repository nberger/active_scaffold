module ActiveScaffold
  module Search
    # AST begin
    def reset_search
      update_table
    end
    # AST end
    
    def reset_search_session_info
      active_scaffold_session_storage[:search] = {}
    end

    def store_params_into_search_session_info
      active_scaffold_session_storage[:search] = params[:search] if params[:search]
    end
    
    def search_session_info
      active_scaffold_session_storage[:search] || {}
    end
  end
end