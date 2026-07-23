# frozen_string_literal: true

class OutreachCampaign < ApplicationRecord
  include OrganizationScoped

  STATUS_ACTIVE = "active"
  STATUS_PAUSED = "paused"
  STATUS_COMPLETED = "completed"
  STATUSES = [STATUS_ACTIVE, STATUS_PAUSED, STATUS_COMPLETED].freeze

  belongs_to :outreach_plan
  has_many :enrollments, class_name: "OutreachEnrollment", dependent: :destroy

  validates :name, :status, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }
  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :excluding_completed, -> { where.not(status: STATUS_COMPLETED) }

  def active?
    status == STATUS_ACTIVE
  end

  def completed?
    status == STATUS_COMPLETED
  end

  def open_for_enrollment?
    status == STATUS_ACTIVE
  end

  def enrollment_count
    enrollments.open.count
  end
end
