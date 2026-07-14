class QbInvoice < ApplicationRecord
  include OrganizationScoped

    belongs_to :customer

    before_validation :assign_organization_from_customer, on: :create

    private

    def assign_organization_from_customer
      self.organization_id ||= customer&.organization_id || Current.organization_id
    end
  end