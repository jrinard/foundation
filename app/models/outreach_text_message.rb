# frozen_string_literal: true

class OutreachTextMessage < ApplicationRecord
  include OrganizationScoped

  DIRECTION_OUTBOUND = "outbound"
  DIRECTION_INBOUND = "inbound"
  DIRECTIONS = [DIRECTION_OUTBOUND, DIRECTION_INBOUND].freeze

  STATUS_RECORDED = "recorded"
  STATUS_SENT = "sent"
  STATUS_DELIVERED = "delivered"
  STATUS_FAILED = "failed"
  STATUSES = [STATUS_RECORDED, STATUS_SENT, STATUS_DELIVERED, STATUS_FAILED].freeze

  belongs_to :outreach_enrollment
  belongs_to :customer
  belongs_to :user, optional: true

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :body, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :chronological, -> { order(created_at: :asc) }
  scope :for_thread, ->(enrollment:) { where(outreach_enrollment: enrollment).chronological }
  scope :outbound, -> { where(direction: DIRECTION_OUTBOUND) }
  scope :inbound, -> { where(direction: DIRECTION_INBOUND) }

  def outbound?
    direction == DIRECTION_OUTBOUND
  end

  def inbound?
    direction == DIRECTION_INBOUND
  end
end
