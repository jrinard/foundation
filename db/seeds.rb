# Foundation — multi-org seed data

DEFAULT_PIPELINE_STAGES = ["Prospect", "Contacted", "Proposal", "Won", "Lost"].freeze

def seed_organization!(slug:, name:, sales_pipeline: true, operations: false, quickbooks: false, **nav_overrides)
  org = Organization.find_or_initialize_by(slug: slug)
  org.assign_attributes(
    name: name,
    sales_pipeline_enabled: sales_pipeline,
    potentials_enabled: nav_overrides.fetch(:potentials_enabled, sales_pipeline),
    leads_enabled: nav_overrides.fetch(:leads_enabled, sales_pipeline),
    current_clients_enabled: nav_overrides.fetch(:current_clients_enabled, true),
    archived_enabled: nav_overrides.fetch(:archived_enabled, true),
    activity_enabled: nav_overrides.fetch(:activity_enabled, true),
    operations_enabled: operations,
    quickbooks_enabled: quickbooks
  )
  org.save!

  Current.organization = org

  DEFAULT_PIPELINE_STAGES.each_with_index do |stage_name, index|
    list = List.find_or_initialize_by(organization: org, name: stage_name)
    list.assign_attributes(
      row_order: index,
      default_for_new_leads: stage_name == "Prospect"
    )
    list.save!
  end

  Offering.find_or_create_by!(organization: org, main: true)

  SiteSetting.find_or_create_by!(organization: org) do |setting|
    setting.show_customer_offerings_section = true
    setting.show_customer_revenue_section = true
  end

  Stats.find_or_create_by!(organization: org, main: true) do |stat|
    stat.month_by_text = Time.zone.today.strftime("%B")
    stat.month_by_number = Time.zone.today.month
    stat.year_by_text = Time.zone.today.strftime("%Y")
    stat.year_by_number = Time.zone.today.year
  end

  org
end

def seed_user!(email:, name:, role:, organization:, password: "1234567890", position: nil)
  user = User.find_or_initialize_by(email: email)
  user.assign_attributes(
    name: name,
    role: role,
    position: position || name
  )
  user.password = password if user.new_record? || user.password.blank?
  user.save!

  OrganizationMembership.find_or_create_by!(user: user, organization: organization)

  user
end

def seed_sample_customer!(organization:, name:)
  Current.organization = organization
  Customer.find_or_create_by!(organization: organization, name: name) do |customer|
    customer.onBoard = "Lead on Board"
    customer.list_id = List.default_for_new_leads_id(organization: organization)
    customer.active = false
    customer.archived = false
  end
end

if (default_org = Organization.find_by(slug: "default")) && Organization.where.not(id: default_org.id).none?
  default_org.update!(
    name: "Echelon Demo",
    slug: "echelon-demo",
    sales_pipeline_enabled: true
  )
end

echelon = Organization.find_by(slug: "echelon-demo") || seed_organization!(
  slug: "echelon-demo",
  name: "Echelon Demo",
  sales_pipeline: true
)

ridgefield = Organization.find_by(slug: "ridgefield-demo") || seed_organization!(
  slug: "ridgefield-demo",
  name: "Ridgefield Demo",
  sales_pipeline: false,
  operations: true,
  quickbooks: true
)

seed_user!(
  email: "josh@lifespringdesign.com",
  name: "Joshua Rinard",
  role: "superadmin",
  organization: echelon,
  position: "Owner"
)

seed_user!(
  email: "admin@echelon-demo.com",
  name: "Echelon Admin",
  role: "admin",
  organization: echelon,
  position: "Admin"
)

seed_user!(
  email: "admin@ridgefield-demo.com",
  name: "Ridgefield Admin",
  role: "admin",
  organization: ridgefield,
  position: "Admin"
)

seed_sample_customer!(organization: echelon, name: "Echelon Sample Lead")
seed_sample_customer!(organization: ridgefield, name: "Ridgefield Sample Customer")

Current.reset

puts "Organizations: #{Organization.pluck(:slug).join(', ')}"
puts "Superadmin: josh@lifespringdesign.com / 1234567890"
puts "Echelon admin: admin@echelon-demo.com / 1234567890"
puts "Ridgefield admin: admin@ridgefield-demo.com / 1234567890"
