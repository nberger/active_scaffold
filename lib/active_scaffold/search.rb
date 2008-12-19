module ActiveScaffold
  module Search
    def reset_search_session_info
      params[:search] = active_scaffold_session_storage[:search] = {} if params[:action] == :reset_search.to_s
    end

    def store_params_into_search_session_info
      active_scaffold_session_storage[:search] = params[:search] if params[:search]
    end
    
    def search_session_info
      active_scaffold_session_storage[:search] || {}
    end
  end
end