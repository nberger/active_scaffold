# The view_paths functionality in Edge Rails (Rails 2.0) doesn't support
# the idea of a fallback generic template file, such as what make ActiveScaffold
# work. This patch adds generic_view_paths, which are folders containing templates
# that may apply to all controllers.
#
# There is one major difference with generic_view_paths, though. They should
# *not* be used unless the action has been explicitly defined in the controller.
# This is in contrast to how Rails will normally bypass the controller if it sees
# a partial.

class ActionController::Base
  class_inheritable_accessor :generic_view_paths
  self.generic_view_paths = []
end

# This hooks into edge rails as of revision 8804 (desparately need the new polymorphic eagerloading from edge)
module ActionView
  class TemplateFinder
    def pick_template_with_generic_paths(template_path, extension)
      path = pick_template_without_generic_paths(template_path, extension)
      if path && !path.empty?
        path
      else
        template_file = File.basename(template_path)
        template_path = find_generic_base_path_for(template_file, extension)
        # ACC return absolute path to file
        template_path
      end
    end
    alias_method_chain :pick_template, :generic_paths
    alias_method :template_exists?, :pick_template

    # Returns the view path that contains the relative template 
    def find_generic_base_path_for(template_file_name, extension)
      # ACC TODO use more robust method of setting this path
      path = RAILS_ROOT + '/vendor/plugins/active_scaffold/frontends/default/views'
      # Should be able to use a rails method here to do this directory search
      file = Dir.entries(path).find {|f| f =~ /^_?#{template_file_name}\.?#{extension}/ }
      file ? File.join(path, file) : nil
    end

    def find_template_extension_from_handler_with_generics(template_path, template_format = @template.template_format)
      t_ext = find_template_extension_from_handler_without_generics(template_path, template_format)
      if t_ext && !t_ext.empty?
        t_ext
      else
        'html.erb'
      end
    end
    alias_method_chain :find_template_extension_from_handler, :generics
  end
end