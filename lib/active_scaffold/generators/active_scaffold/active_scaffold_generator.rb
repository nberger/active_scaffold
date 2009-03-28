class Rails::Generator::Commands::Base
  private
    def template_part_mark(name, id)
      name ? "<!--[#{name}:#{id}]-->\n" : ""
    end
end

class ScaffoldingSandbox
  include ActionView::Helpers::ActiveRecordHelper

  attr_accessor :form_action, :singular_name, :suffix, :model_instance

  def sandbox_binding
    binding
  end
  
  # def default_input_block
  #   Proc.new { |record, column| "<p><label for=\"#{record}_#{column.name}\">#{column.human_name}</label><br/>\n#{input(record, column.name)}</p>\n" }
  # end

  def default_input_block
    input_block = Proc.new { |record, column| "
      <li class=\"form-element <%= 'required' if active_scaffold_config.columns[:#{column.name}].required? %>\">
        <dl>
          <dt>
            <label for=\"record_#{column.name}\"><%= active_scaffold_config.columns[:#{column.name}].label %></label>
          </dt>
          <dd>
            <%= active_scaffold_input_for active_scaffold_config.columns[:#{column.name}] %>
              <span class=\"description\"><%= active_scaffold_config.columns[:#{column.name}].description %></span>
          </dd>
        </dl>
      </li>"}
  end

  def default_show_block
    input_block = Proc.new { |record, column| "
          <dt><%= active_scaffold_config.columns[:#{column.name}].label -%></dt>
          <dd><%= get_column_value(@record, active_scaffold_config.columns[:#{column.name}]) -%> &nbsp;</dd>"}
  end

  def default_column_block
    Proc.new { |record, column| 
      column_name = column.name
      column_name = column_name[0..-4] if column_name[-3, 3] == "_id"
"      [:#{column_name} => {
        :exclude => [:field_search, :list]
      }]," }
  end

  def all_columns(record, record_name, options) 
    if options[:has_columns]
      input_block = options[:input_block] || default_column_block
    elsif options[:show_columns]
      input_block = options[:input_block] || default_show_block
    else
      input_block = options[:input_block] || default_input_block
    end

    if !options[:exclude].blank?
      filtered_content_columns = record.class.columns.reject { |column| options[:exclude].include?(column.name) }
    else
      filtered_content_columns = record.class.columns
    end

    filtered_content_columns.collect{ |column| input_block.call(record_name, column) }.join("\n")
  end
  
end

module ActionView::Helpers::ActiveRecordHelper
  
  def all_input_tags(record, record_name, options)
    input_block = options[:input_block] || default_input_block
    skip_columns = ["created_at", "lock_version", "created_on", "updated_at", "updated_on"]
    @results = record.class.content_columns.collect do |column|
     unless skip_columns.detect{|c| c == column.name}  || column.name.last(3) == "id"
       input_block.call(record_name, column) 
     end
    end
    @results.join("")
  end
  
  def all_associations(record)
     @results =""
     puts record.class.reflect_on_all_associations.inspect
     record.class.reflect_on_all_associations.each do |a|
      puts a.inspect
      if a.macro == :belongs_to
        @results += "<p>#{a.klass}<br/><%=f.select #{a.klass}.find(:all).collect {|i| [ p.inspect, p.id ] }, { :include_blank => true }) %>"
      end
    end
    @results
  end
  
  def quote(value)
    case value
      when NilClass                 then "NULL"
      when TrueClass                then "TRUE"
      when FalseClass               then "FALSE"
      when Float, Fixnum, Bignum    then value.to_s
      # BigDecimals need to be output in a non-normalized form and quoted.
      when BigDecimal               then value.to_s('F')
      else
        value.inspect
    end
  end
  
end


class ActionView::Helpers::InstanceTag
  def to_tag(options = {})
    case column_type
      when :string
        field_type = @method_name.include?("password") ? "password" : "text"
        to_input_field_tag(field_type, options)
      when :text
        to_text_area_tag(options)
      when :integer, :float, :decimal
        to_input_field_tag("text", options)
      when :date
        to_date_select_tag(options)
      when :datetime, :timestamp
        to_datetime_select_tag(options)
      when :time
        to_time_select_tag(options)
      when :boolean
        to_boolean_checkbox_tag(options)
    end
  end
  
  def to_input_field_tag(field_type, options={})
    field_meth = "#{field_type}_field"
    "<%= f.#{field_meth} '#{@method_name}' #{options.empty? ? '' : ', '+options.inspect} %>"
  end

  def to_boolean_checkbox_tag(options = {})
    "<%= f.check_box '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect} %>"
  end
  
  def to_text_area_tag(options = {})
    "<%= f.text_area '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect} %>"
  end

  def to_date_select_tag(options = {})
    "<%= f.date_select '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect} %>"
  end

  def to_datetime_select_tag(options = {})
       "<%= f.datetime_select '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect} %>"
  end
  
  def to_time_select_tag(options = {})
    "<%= f.time_select '#{@method_name}' #{options.empty? ? '' : ', '+ options.inspect} %>"
  end

  alias_method :base_to_input_field_tag, :to_input_field_tag

  def to_input_field_tag(field_type, options={})
    options[:class] = 'text-input'  
    base_to_input_field_tag field_type, options
  end
  
  def to_boolean_select_tag(options = {})
    options = options.stringify_keys
    add_default_name_and_id(options)
    tag_text = "<%= select \"#{@object_name}\", \"#{@method_name}\", [[\"True\", true], [\"False\", false]], { :selected => @#{@object_name}.#{@method_name} } %>"
  end

end

class ActiveScaffoldGenerator < Rails::Generator::NamedBase
  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_singular_name,
                :controller_plural_name
  alias_method  :controller_file_name,  :controller_singular_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super

    # Take controller name from the next argument.  Default to the pluralized model name.
    @controller_name = args.shift
    @controller_name ||= ActiveRecord::Base.pluralize_table_names ? @name.pluralize : @name

    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_singular_name, @controller_plural_name = inflect_names(base_name)

    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end
  end

  # def controller_file_path
  #   "/" + base_controller_file_path
  # end
  # 
  def manifest
    record do |m|
      # # Check for class naming collisions.
      # m.class_collisions controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}ControllerTest", "#{controller_class_name}Helper"

      # Controller, helper, views, and test directories.

      # Model, controller, helper, views, and test directories.
      m.directory File.join('app/models', class_path)
      m.directory File.join('test/unit', class_path)
      # I use factories
      # m.directory File.join('test/fixtures', class_path)
      m.directory File.join('app/controllers', controller_class_path)
      m.directory File.join('app/helpers', controller_class_path)
      m.directory File.join('app/views', controller_class_path, controller_file_name)
      m.directory File.join('app/views/layouts', controller_class_path)
      m.directory File.join('test/functional', controller_class_path)

      # Unit test, and fixtures.
      m.template 'unit_test.rb',  File.join('test/unit', "#{singular_name}_test.rb")
      # I use factories
      # m.template 'fixtures.yml',  File.join('test/fixtures', "#{singular_name}.yml")

      m.complex_template 'model.rb',
        File.join('app/models', "#{singular_name}.rb"),
        :insert => 'model_scaffolding.rhtml',
        :sandbox => lambda { create_sandbox }

      m.complex_template('form.rhtml',
        File.join('app/views',
                  controller_class_path,
                  controller_file_name,
                  '_form.rhtml'),
        :insert => 'form_scaffolding.rhtml',
        :sandbox => lambda { create_sandbox },
        :begin_mark => 'form',
        :end_mark => 'eoform',
        :mark_id => singular_name) if less_dry_partial?

      m.complex_template('show.rhtml',
        File.join('app/views',
                  controller_class_path,
                  controller_file_name,
                  '_show.rhtml'),
        :insert => 'show_scaffolding.rhtml',
        :sandbox => lambda { create_sandbox },
        :begin_mark => 'show',
        :end_mark => 'eoshow',
        :mark_id => singular_name) if less_dry_partial?

      # Controller class, functional test, helper, and views.
      m.template('functional_test.rb', File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb"))
      controller_template_name = 'controller_methods.rb'
      m.complex_template controller_template_name,
        File.join('app/controllers',
                controller_class_path,
                "#{controller_file_name}_controller.rb"),
        :insert => 'controller_scaffolding.rhtml',
        :sandbox => lambda { create_sandbox }
      m.template 'helper.rb',
        File.join('app/helpers',
                  controller_class_path,
                  "#{controller_file_name}_helper.rb")  

    end
  end

  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} scaffold ModelName [ControllerName]"
    end

    def less_dry_partial?
      args.include?("less_dry")
    end

    def scaffold_views
      []
    end

    def model_name 
      class_name.demodulize
    end

    def suffix
      "_#{singular_name}" if options[:suffix]
    end

    def create_sandbox
      sandbox = ScaffoldingSandbox.new
      sandbox.singular_name = singular_name
      begin
        sandbox.model_instance = model_instance
        sandbox.instance_variable_set("@#{singular_name}", sandbox.model_instance)
      rescue ActiveRecord::StatementInvalid => e
        logger.error "Before updating scaffolding from new DB schema, try creating a table for your model (#{class_name})"
        raise SystemExit
      end
      sandbox.suffix = suffix
      sandbox
    end
    
    def model_instance
      base = class_nesting.split('::').inject(Object) do |base, nested|
        break base.const_get(nested) if base.const_defined?(nested)
        base.const_set(nested, Module.new)
      end
      unless base.const_defined?(@class_name_without_nesting)
        base.const_set(@class_name_without_nesting, Class.new(ActiveRecord::Base))
      end
      class_name.constantize.new
    end
end
