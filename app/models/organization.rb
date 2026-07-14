class Organization < ApplicationRecord
  has_many :organization_memberships, dependent: :destroy
  has_many :users, through: :organization_memberships
  has_many :customers, dependent: :destroy
  has_many :lists, dependent: :destroy
  has_many :leads, dependent: :destroy
  has_many :offerings, dependent: :destroy
  has_many :stats, class_name: "Stats", dependent: :destroy
  has_many :site_settings, class_name: "SiteSetting", dependent: :destroy
  has_many :quickbooks_tokens, dependent: :destroy
  has_one :quickbooks_token, dependent: :destroy

  INDEX_SORT_OPTIONS = %w[name recent quickbooks].freeze
  INDEX_SORT_DEFAULT = "name".freeze

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  NAV_MODULES = %w[potentials leads current_clients archived activity].freeze

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :apply_legacy_sales_pipeline_checkbox, if: :will_save_change_to_sales_pipeline_enabled?
  before_save :sync_legacy_sales_pipeline_flag
  before_validation :generate_slug, on: :create
  before_validation :normalize_slug, if: :will_save_change_to_slug?

  def sales_pipeline_enabled?
    potentials_enabled? || leads_enabled?
  end

  def potentials_enabled?
    potentials_enabled
  end

  def leads_enabled?
    leads_enabled
  end

  def current_clients_enabled?
    current_clients_enabled
  end

  def archived_enabled?
    archived_enabled
  end

  def activity_enabled?
    activity_enabled
  end

  def quickbooks_enabled?
    quickbooks_enabled
  end

  def operations_enabled?
    operations_enabled
  end

  def discovery_enabled?
    discovery_enabled
  end

  def member_count
    organization_memberships.count
  end

  def deactivate!
    update!(active: false)
  end

  def module_badges
    badges = []
    badges << "Potentials" if potentials_enabled?
    badges << "Leads" if leads_enabled?
    badges << "Clients" if current_clients_enabled?
    badges << "Archived" if archived_enabled?
    badges << "Activity" if activity_enabled?
    badges << "QuickBooks" if quickbooks_enabled?
    badges << "Operations" if operations_enabled?
    badges << "Discovery" if discovery_enabled?
    badges
  end

  def provision_defaults!
    previous_org = Current.organization
    Current.organization = self

    %w[Prospect Contacted Proposal Won Lost].each_with_index do |stage_name, index|
      list = lists.find_or_initialize_by(name: stage_name)
      list.assign_attributes(
        row_order: index,
        default_for_new_leads: stage_name == "Prospect"
      )
      list.save!
    end

    offerings.find_or_create_by!(main: true)
    site_settings.find_or_create_by!(organization_id: id) do |setting|
      setting.show_customer_offerings_section = true
      setting.show_customer_revenue_section = true
    end
    stats.find_or_create_by!(organization_id: id, main: true)
  ensure
    Current.organization = previous_org
  end

  private

  def apply_legacy_sales_pipeline_checkbox
    if sales_pipeline_enabled?
      self.potentials_enabled = true unless will_save_change_to_potentials_enabled?
      self.leads_enabled = true unless will_save_change_to_leads_enabled?
    else
      self.potentials_enabled = false
      self.leads_enabled = false
    end
  end

  def sync_legacy_sales_pipeline_flag
    self.sales_pipeline_enabled = potentials_enabled? || leads_enabled?
  end

  def generate_slug
    return if slug.present?

    base = name.to_s.parameterize
    candidate = base
    suffix = 2
    while Organization.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence
  end
end
