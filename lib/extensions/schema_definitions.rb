module ActiveRecord
  module ConnectionAdapters #:nodoc:
    class TableDefinition
      def timestamps(*args)
        options = args.extract_options!
        lock_version = options.delete(:lock_version).nil?
        column(:created_at, :datetime, options)
        column(:updated_at, :datetime, options)
        column(:lock_version, :integer, {:null => false, :default => 0}) if lock_version
      end
    end
  end
end
