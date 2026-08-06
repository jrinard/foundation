module ApplicationHelper
  def active_class(link_path)
    current_page?(link_path) ? "active" : ""
  end

  def prospects_list_params(extra = {})
    params.permit(:sort_by, :filter_by, :sort_by_manager, :sort_by_offering, :sort_by_service, :l).to_h.merge(extra)
  end

  def prospect_source_badge(customer)
    Lifespring::WebsiteSources.badge_for(customer.sms_opt_in_source)
  end

  def sms_opt_in_source_options_for_select(customer)
    options_for_select(
      Lifespring::WebsiteSources.select_options,
      Lifespring::WebsiteSources.selected_value_for(customer.sms_opt_in_source)
    )
  end

  def website_contact_form_prospect?(customer)
    customer.website_contact_form_opt_in?
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
