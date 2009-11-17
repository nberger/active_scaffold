module ActiveRecord
  module ConnectionAdapters #:nodoc:
    class TableDefinition
      def timestamps(*args)
        options = args.extract_options!
        lock_version = options.delete(:lock_version).nil?
        deleted_at = options.delete(:deleted_at)
        column(:created_at, :datetime, options)
        column(:deleted_at, :datetime, options) if deleted_at
        column(:updated_at, :datetime, options)
        column(:lock_version, :integer, {:null => false, :default => 0}) if lock_version
      end
    end
  end
end
