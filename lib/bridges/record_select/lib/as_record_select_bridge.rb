module ActiveScaffold::Config
  class Core < Base

    def initialize_with_record_select(config_options)
      initialize_without_record_select(config_options)
      
      config_options[:controller].generic_view_paths << File.join(Rails.root, 'vendor', 'plugins', 'record_select', 'lib', 'views')
      config_options[:controller].generic_view_paths.flatten!

      # Not sure how helpful this is.
      # record_select_fields = self.model.columns.collect{|c| c.name.to_sym if [:integer].include?(c.type) and c.name[-3,3] == '_id' }.compact
      # # check to see if file column was used on the model
      # return if record_select_fields.empty?
      # 
      # # automatically set the forum_ui to a file column
      # record_select_fields.each{|field|
      #   self.columns[field].form_ui = :record_select
      # }
    end
    
    alias_method_chain :initialize, :record_select
    
  end
end
