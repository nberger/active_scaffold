module ActiveScaffold::Config
  class Refresh < Base
    self.crud_type = :read

    def initialize(core_config)
      @core = core_config

      # start with the ActionLink defined globally
      @link = self.class.link.clone
    end


    # global level configuration
    # --------------------------
    # the ActionLink for this action
    cattr_reader :link
    @@link = ActiveScaffold::DataStructures::ActionLink.new('refresh', :label => :refresh, :type => :table, :inline => true, :position => false, :security_method => :list_authorized?)

    # the ActionLink for this action
    attr_accessor :link
  end
end
