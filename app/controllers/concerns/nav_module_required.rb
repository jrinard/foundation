module NavModuleRequired
  extend ActiveSupport::Concern

  class_methods do
    def require_nav_module(module_name)
      before_action -> { enforce_nav_module!(module_name) }
    end
  end

  private

  def enforce_nav_module!(module_name)
    return if current_user&.superadmin?

    org = current_organization
    return unless org

    enabled = org.public_send("#{module_name}_enabled?")
    return if enabled

    redirect_to org_default_path, alert: "#{nav_module_label(module_name)} is not enabled for #{org.name}."
  end

  def nav_module_label(module_name)
    {
      potentials: "Potentials",
      leads: "Leads",
      current_clients: "Current Clients",
      archived: "Archived",
      activity: "Activity",
      discovery: "Discovery"
    }.fetch(module_name.to_sym, module_name.to_s.humanize)
  end
end
