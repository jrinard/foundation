# frozen_string_literal: true

class OutreachPlan < ApplicationRecord
  include OrganizationScoped

  has_many :steps,
           -> { order(:position) },
           class_name: "OutreachPlanStep",
           dependent: :destroy,
           inverse_of: :outreach_plan
  has_many :campaigns, class_name: "OutreachCampaign", dependent: :restrict_with_error

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(:name) }

  DEFAULT_PLAN_NAME = "Emerald Plan"

  def self.default_for_organization(organization = Current.organization)
    return nil unless organization

    active.includes(:steps).find_by(name: DEFAULT_PLAN_NAME) ||
      active.includes(:steps).order(:created_at).first
  end

  accepts_nested_attributes_for :steps, allow_destroy: true, reject_if: :all_blank

  def step_count
    steps.size
  end

  def snapshot_steps
    steps.map(&:snapshot_attributes)
  end
end
