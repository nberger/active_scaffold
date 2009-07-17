class <%= controller_class_name %>Controller < ApplicationController
  before_filter :require_user
  
<%= template_for_inclusion %>

  protected

  # ===================
  # = Authorize BEGIN =
  # ===================
  
  def create_authorized?
    permit?([:root, :super])
  end
  
  def delete_authorized?
    permit?([:root, :super])
  end
  
  def list_authorized?
    permit?([:root, :super])
  end
  
  def show_authorized?
    permit?([:root, :super])
  end
  
  def update_authorized?
    permit?([:root, :super])
  end
  
  # =================
  # = Authorize END =
  # =================

end
