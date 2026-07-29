# frozen_string_literal: true

module Customers
  class TransferOrganization
    def self.call(customer:, organization:)
      new(customer: customer, organization: organization).call
    end

    def initialize(customer:, organization:)
      @customer = customer
      @organization = organization
    end

    def call
      return @customer if @customer.organization_id == @organization.id

      ActiveRecord::Base.transaction do
        enrollment_ids = OutreachEnrollment.unscoped_by_organization.where(customer_id: @customer.id).pluck(:id)

        apply_customer_transfer!
        cascade_organization_id!(@customer.contacts)
        cascade_organization_id!(@customer.notes)
        cascade_organization_id!(@customer.offerings)
        cascade_organization_id!(@customer.discovery_businesses.unscoped_by_organization)
        cascade_organization_id!(@customer.qb_invoices)
        cascade_organization_id!(OutreachEnrollment.unscoped_by_organization.where(id: enrollment_ids))

        if enrollment_ids.any?
          OutreachActivity.unscoped_by_organization.where(outreach_enrollment_id: enrollment_ids)
                          .update_all(organization_id: @organization.id, updated_at: Time.current)
          OutreachTextMessage.unscoped_by_organization.where(outreach_enrollment_id: enrollment_ids)
                             .update_all(organization_id: @organization.id, updated_at: Time.current)
        end
      end

      @customer.reload
    end

    private

    def apply_customer_transfer!
      updates = {
        organization_id: @organization.id,
        list_id: nil
      }
      updates[:user_id] = nil unless account_manager_in_target_org?

      @customer.update!(updates)
    end

    def account_manager_in_target_org?
      return false if @customer.user_id.blank?

      @organization.users.exists?(id: @customer.user_id)
    end

    def cascade_organization_id!(relation)
      relation.update_all(organization_id: @organization.id, updated_at: Time.current)
    end
  end
end
