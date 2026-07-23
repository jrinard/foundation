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

# Dev-only: Discovery → scored → promoted prospects for Outreach / Potentials UI work.
def seed_dev_prospect_with_scorecard!(organization:, ubi:, business_name:, **attrs)
  Current.organization = organization

  business = DiscoveryBusiness.find_or_initialize_by(
    organization: organization,
    source: DiscoveryBusiness::SOURCE_WA_SOS,
    external_id: ubi
  )

  office_address = attrs.fetch(:office_address)
  vertical = attrs.fetch(:vertical)
  captured_at = attrs.fetch(:captured_at, 5.days.ago)

  business.assign_attributes(
    business_name: business_name,
    business_type: "WA LIMITED LIABILITY COMPANY",
    office_address: office_address,
    registered_agent_name: "Registered Agent Services LLC",
    city: attrs.fetch(:city, "Vancouver"),
    filter_city: "Vancouver",
    raw_payload: { "Business Name" => business_name, "UBI#" => ubi },
    phone: attrs.fetch(:phone),
    email: attrs.fetch(:email),
    website: attrs[:website],
    vertical_classification: vertical,
    google_place_id: attrs[:google_place_id],
    google_rating: attrs[:google_rating],
    google_rating_count: attrs[:google_rating_count],
    advanced_captured_at: captured_at,
    places_check_status: attrs.fetch(:places_check_status, DiscoveryBusiness::CHECK_FOUND),
    website_check_status: attrs.fetch(:website_check_status, DiscoveryBusiness::CHECK_MISSING),
    facebook_check_status: attrs.fetch(:facebook_check_status, DiscoveryBusiness::CHECK_MISSING),
    linkedin_check_status: attrs.fetch(:linkedin_check_status, DiscoveryBusiness::CHECK_MISSING),
    instagram_check_status: attrs.fetch(:instagram_check_status, DiscoveryBusiness::CHECK_UNCHECKED),
    brand_check_status: attrs.fetch(:brand_check_status, DiscoveryBusiness::CHECK_UNCHECKED),
    hosting_check_status: attrs.fetch(:hosting_check_status, DiscoveryBusiness::CHECK_UNCHECKED)
  )

  if business.promoted?
    business.archived = true
  else
    business.status = DiscoveryBusiness::STATUS_DISCOVERY
    business.archived = false
  end

  business.save!

  Discovery::PersistOpportunityScore.call(discovery_business: business)
  Discovery::PromoteToPotential.call(discovery_business: business.reload) unless business.promoted?

  business.reload.customer
end

if (default_org = Organization.find_by(slug: "default")) && Organization.where.not(id: default_org.id).none?
  default_org.update!(
    name: "Echelon Demo",
    slug: "echelon-demo",
    sales_pipeline_enabled: true
  )
end

lifespring = Organization.find_by(slug: "lifespring") || seed_organization!(
  slug: "lifespring",
  name: "LifeSpring Design",
  sales_pipeline: true
)
lifespring.update!(discovery_enabled: true) unless lifespring.discovery_enabled?
lifespring.update!(outreach_enabled: true) unless lifespring.outreach_enabled?
DiscoverySource.ensure_wa_sos!(lifespring)
Outreach::SeedDefaultPlans.call(organization: lifespring) if lifespring.outreach_enabled?

Current.organization = lifespring
unless OutreachCampaign.exists?(organization: lifespring)
  plan = OutreachPlan.default_for_organization(lifespring)
  OutreachCampaign.create!(
    organization: lifespring,
    outreach_plan: plan,
    name: "New Business Acquisition Campaign",
    description: "Convert qualified Prospects into customers — new businesses, high score, local.",
    status: OutreachCampaign::STATUS_ACTIVE,
    cohort_goal: 30
  )
end

echelon = Organization.find_by(slug: "echelon-demo") || seed_organization!(
  slug: "echelon-demo",
  name: "Echelon Demo",
  sales_pipeline: true
)

echelon.update!(discovery_enabled: true) unless echelon.discovery_enabled?
DiscoverySource.ensure_wa_sos!(echelon)

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

Current.organization = lifespring

seed_dev_prospect_with_scorecard!(
  organization: lifespring,
  ubi: "999000001",
  business_name: "Evergreen Exterior Cleaning LLC",
  office_address: "1842 Main St, Vancouver, WA, 98660, UNITED STATES",
  phone: "(360) 555-0142",
  email: "owner@evergreenexterior.example",
  vertical: "Pressure Washing",
  google_place_id: "ChIJdev-evergreen-exterior",
  google_rating: 4.7,
  google_rating_count: 3,
  captured_at: 4.days.ago,
  website_check_status: DiscoveryBusiness::CHECK_MISSING,
  places_check_status: DiscoveryBusiness::CHECK_FOUND,
  facebook_check_status: DiscoveryBusiness::CHECK_MISSING,
  linkedin_check_status: DiscoveryBusiness::CHECK_MISSING
)

seed_dev_prospect_with_scorecard!(
  organization: lifespring,
  ubi: "999000002",
  business_name: "Northwest Plumbing & Heating LLC",
  office_address: "520 NE 78th St, Vancouver, WA, 98665, UNITED STATES",
  phone: "(360) 555-0198",
  email: "service@nwplumbing.example",
  website: "https://nwplumbing.example",
  vertical: "Plumbing",
  google_place_id: "ChIJdev-nw-plumbing",
  google_rating: 3.2,
  google_rating_count: 8,
  captured_at: 12.days.ago,
  website_check_status: DiscoveryBusiness::CHECK_FOUND,
  places_check_status: DiscoveryBusiness::CHECK_FOUND,
  facebook_check_status: DiscoveryBusiness::CHECK_FOUND,
  linkedin_check_status: DiscoveryBusiness::CHECK_MISSING,
  hosting_check_status: DiscoveryBusiness::CHECK_UNCHECKED
)

Current.reset

puts "Organizations: #{Organization.pluck(:slug).join(', ')}"
puts "Superadmin: josh@lifespringdesign.com / 1234567890"
puts "Echelon admin: admin@echelon-demo.com / 1234567890"
puts "Ridgefield admin: admin@ridgefield-demo.com / 1234567890"
puts "LifeSpring dev prospects: Evergreen Exterior Cleaning LLC, Northwest Plumbing & Heating LLC (Potentials + scorecards)"
