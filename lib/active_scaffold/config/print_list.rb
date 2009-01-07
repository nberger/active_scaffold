module ActiveScaffold::Config
  class PrintList < PrintBase
    
    self.crud_type = :read

    def initialize(core_config)
      super

      @font_size = self.class.font_size
      # # old print_pdf stuff
      # @footer_font_size = self.class.footer_font_size
      # @header_font_size = self.class.header_font_size
      # @header_image = self.class.header_image
      # @header_size = self.class.header_size
      # @header_text = self.class.header_text
      # @orientation = self.class.orientation
    end

    # global level configuration
    # --------------------------
    # the ActionLink for this action
    cattr_reader :link
    @@link = ActiveScaffold::DataStructures::ActionLink.new('print_list', :label => :print, :type => :table, :security_method => :print_list_authorized?, :popup => true)
    
    cattr_accessor :font_size
    @@font_size = 8
    # cattr_accessor :footer_font_size
    # @@footer_font_size = 8
    # cattr_accessor :header_font_size
    # @@header_font_size = 8
    # cattr_accessor :header_image
    # @@header_image = nil
    # cattr_accessor :header_size
    # @@header_size = 10
    cattr_accessor :header_text
    @@header_text = ''
    # cattr_accessor :orientation
    # @@orientation = 'L'
    
    # instance-level configuration
    # ----------------------------

    attr_accessor :font_size
    # attr_accessor :footer_font_size
    # attr_accessor :header_font_size
    # attr_accessor :header_image
    # attr_accessor :header_size
    attr_accessor :header_text
    # attr_accessor :orientation
    
  end
end
