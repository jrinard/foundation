module ApplicationHelper
  def active_class(link_path)
    current_page?(link_path) ? "active" : ""
  end

  #This is the one that works
  # def body_class
  #   if controller_name == 'customers'
  #     'dark-body'
  #   else
  #     'light-body'
  #   end
  # end
end
