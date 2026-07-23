# frozen_string_literal: true

class OutreachActivity < ApplicationRecord
  include OrganizationScoped

  belongs_to :outreach_enrollment
  belongs_to :user, optional: true

  validates :activity_type, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
