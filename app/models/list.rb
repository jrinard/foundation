class List < ApplicationRecord
  include OrganizationScoped

  # validates :name, presence: true
  has_many :customers

  include RankedModel
  ranks :row_order

  before_save :normalize_stats_exclusion_label
  before_save :ensure_single_default_for_new_leads

  scope :default_for_new_leads, -> { where(default_for_new_leads: true) }

  # label: nil/empty = include column in kanban stats bar; "excluded" = omit from stats.
  def include_in_stats_bar?
    !excluded_from_stats_bar?
  end

  def excluded_from_stats_bar?
    s = label.to_s.strip
    s == "excluded" || s == "false"
  end

  def self.default_for_new_leads_id(organization: Current.organization)
    scope = organization ? where(organization_id: organization.id) : all
    scope.default_for_new_leads.order(:id).pick(:id) || scope.order(:id).pick(:id)
  end

  private

  def normalize_stats_exclusion_label
    # Persist only nil or "excluded"; legacy "false" / "true" from older UI are normalized here.
    self.label = excluded_from_stats_bar? ? "excluded" : nil
  end

  def ensure_single_default_for_new_leads
    return unless default_for_new_leads?

    List.unscoped.where(organization_id: organization_id)
        .where.not(id: id)
        .where(default_for_new_leads: true)
        .update_all(default_for_new_leads: false)
  end
end
