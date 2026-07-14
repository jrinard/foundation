class SiteSetting < ApplicationRecord
  include OrganizationScoped

  def self.record
    org = Current.organization
    raise "Current organization is required" if org.nil?

    where(organization_id: org.id).first ||
      create!(
        organization: org,
        show_customer_offerings_section: true,
        show_customer_revenue_section: true
      )
  end

  def self.customer_offerings_section_visible?
    record.show_customer_offerings_section
  end

  def self.set_customer_offerings_section_visible!(visible)
    record.update!(show_customer_offerings_section: visible)
  end

  def self.toggle_customer_offerings_section!
    set_customer_offerings_section_visible!(!customer_offerings_section_visible?)
  end

  def self.customer_revenue_section_visible?
    record.show_customer_revenue_section
  end

  def self.set_customer_revenue_section_visible!(visible)
    record.update!(show_customer_revenue_section: visible)
  end

  def self.toggle_customer_revenue_section!
    set_customer_revenue_section_visible!(!customer_revenue_section_visible?)
  end
end
