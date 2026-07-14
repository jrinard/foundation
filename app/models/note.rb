class Note < ApplicationRecord
  include OrganizationScoped

  belongs_to :customer, optional: true
  belongs_to :user, optional: true

  before_validation :assign_organization_from_customer, on: :create

  private

  def assign_organization_from_customer
    self.organization_id ||= customer&.organization_id || Current.organization_id
  end
end
