class Object
  def as_(key, options = {})
    unless key.blank?
			# options[:default] ||= key.to_s.titleize unless ActiveScaffold::Config::Core.show_missing_translations
			# options[:default] = nil if ActiveScaffold::Config::Core.show_missing_translations
      # text = I18n.translate "#{key}", {:scope => [:active_scaffold]}.merge(options)
      text = I18n.translate "#{key}", {:scope => [:active_scaffold], :default => key.is_a?(String) ? key : key.to_s.titleize}.merge(options)
    end
    text
  end
end
