module ActiveScaffold::Actions
  module List
    include ActiveScaffold::Search
    def self.included(base)
      base.before_filter :list_authorized?, :only => [:index, :table, :update_table, :row, :list]
    end

    def index
      list
    end

    def table
      do_list
      render(:action => 'list', :layout => false)
    end

    # This is called when changing pages, sorts and search
    def update_table
      respond_to do |type|
        type.js do
          do_list
          render(:partial => 'list', :layout => false)
        end
        type.html { return_to_main }
      end
    end

    # get just a single row
    def row
      render :partial => 'list_record', :locals => {:record => find_if_allowed(params[:id], :read)}
    end

    def list
      reset_search_session_info
      do_list

      respond_to do |type|
        type.html {
          render :action => 'list', :layout => true
        }
        type.xml { render :xml => response_object.to_xml, :content_type => Mime::XML, :status => response_status }
        type.json { render :text => response_object.to_json, :content_type => Mime::JSON, :status => response_status }
        type.yaml { render :text => response_object.to_yaml, :content_type => Mime::YAML, :status => response_status }
      end
    end

    protected

    # The actual algorithm to prepare for the list view
    def do_list
      includes_for_list_columns = active_scaffold_config.list.columns.collect{ |c| c.includes }.flatten.uniq.compact
      self.active_scaffold_joins.concat includes_for_list_columns

      options = {:sorting => active_scaffold_config.list.user.sorting,}
      paginate = (params[:format].nil?) ? (accepts? :html, :js) : [:html, :js].include?(params[:format])
      if paginate
        options.merge!({
          :per_page => active_scaffold_config.list.user.per_page,
          :page => active_scaffold_config.list.user.page
        })
      end

      page = find_page(options);
      if page.items.empty?
        page = page.pager.first
        active_scaffold_config.list.user.page = 1
      end
      @page, @records = page, page.items
    end

    def do_list_by_sql(select_clause, from_clause, where_clause = nil, order_group_by_clause = nil)
      includes_for_list_columns = active_scaffold_config.list.columns.collect{ |c| c.includes }.flatten.uniq.compact
      self.active_scaffold_joins.concat includes_for_list_columns

      options = {:sorting => active_scaffold_config.list.user.sorting,}
      paginate = (params[:format].nil?) ? (accepts? :html, :js) : [:html, :js].include?(params[:format])
      if paginate
        options.merge!({
          :per_page => active_scaffold_config.list.user.per_page,
          :page => active_scaffold_config.list.user.page
        })
      end

      options[:per_page] ||= 999999999
      options[:page] ||= 1

      klass = active_scaffold_config.model

      if active_scaffold_conditions.length > 0
        where_clause << " AND " if where_clause
        where_clause ||= " Where "
        where_clause << active_scaffold_conditions
      end
      count = klass.count_by_sql("Select count(*) #{from_clause} #{where_clause}" )

      # we build the paginator differently for method- and sql-based sorting
      if options[:sorting] and options[:sorting].sorts_by_method?
        pager = ::Paginator.new(count, options[:per_page]) do |offset, per_page|
          sorted_collection = sort_collection_by_column(klass.find_by_sql("#{select_clause} #{from_clause} #{where_clause} #{order_group_by_clause}"), *options[:sorting].first)
          sorted_collection.slice(offset, per_page)
        end
      else
        pager = ::Paginator.new(count, options[:per_page]) do |offset, per_page|
          klass.find_by_sql("#{select_clause} #{from_clause} #{where_clause} #{order_group_by_clause} Limit #{offset}, #{per_page}")
        end
      end

      page = pager.page(options[:page])

      if page.items.empty?
        page = page.pager.first
        active_scaffold_config.list.user.page = 1
      end
      @page, @records = page, page.items
    end
    
    # The default security delegates to ActiveRecordPermissions.
    # You may override the method to customize.
    def list_authorized?
      authorized_for?(:action => :read)
    end
  end
end