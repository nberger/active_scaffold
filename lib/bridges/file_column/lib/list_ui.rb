module ActiveScaffold
  module Helpers
    # Helpers that assist with the rendering of a List Column
    module ListColumnHelpers
      def active_scaffold_column_download_link_with_filename(column, record)
        return nil if record.send(column.name).nil?
        active_scaffold_column_download_link(column, record, File.basename(record.send(column.name)))
      end

      # HOWTO
      # <% column = active_scaffold_config.columns[:file_name] %>
      # <% doc = Document.find(:first, :conditions => ["name = ?", doc_name]) %>
      # <%= active_scaffold_column_download_link(column, doc) %>
      def active_scaffold_column_download_link(column, record, label = nil)
        return nil if record.send(column.name).nil?
        label ||= as_(:download)
        # AST Begin - :secure_download
        if column.options[:secure_download]
          url_options = active_scaffold_column_download_link_url_options(column, record)
        else
          url_options = url_for_file_column(record, column.name.to_s)
        end
        # AST End
        link_to( label, url_options, :popup => true)
      end
      
      # AST - active_scaffold_column_download_link_url_options
      def active_scaffold_column_download_link_url_options(column, record)
        {:controller => active_scaffold_config.secure_download_controller, :action => "show", :id => record.id, :download => url_for_file_column(record, column.name.to_s)}#.encrypt!(:symmetric, :key => active_scaffold_config.secure_download_key)}
      end
      
      def active_scaffold_column_thumbnail(column, record)
        return nil if record.send(column.name).nil?
        link_to( 
          image_tag(url_for_file_column(record, column.name.to_s, "thumb"), :border => 0), 
          url_for_file_column(record, column.name.to_s), 
          :popup => true)
      end
      
    end
  end
end
