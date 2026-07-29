# frozen_string_literal: true

module Discovery
  class PromoteToPotential
    Result = Struct.new(:customer, :created, :already_promoted, keyword_init: true)

    def self.call(discovery_business:)
      new(discovery_business: discovery_business).call
    end

    def initialize(discovery_business:)
      @discovery_business = discovery_business
      @organization = discovery_business.organization
    end

    def call
      return already_promoted_result if @discovery_business.promoted?

      customer = nil
      created = false

      ActiveRecord::Base.transaction do
        customer = find_existing_customer
        created = customer.nil?

        customer ||= Customer.create!(
          PotentialCustomerFields.customer_attributes(@discovery_business, organization: @organization)
        )
        ensure_registered_agent_contact!(customer)
        @discovery_business.update!(
          status: DiscoveryBusiness::STATUS_PROMOTED,
          customer: customer,
          archived: true
        )
      end

      Result.new(customer: customer, created: created, already_promoted: false)
    end

    private

    def already_promoted_result
      Result.new(
        customer: @discovery_business.customer,
        created: false,
        already_promoted: true
      )
    end

    def find_existing_customer
      if @discovery_business.customer_id.present?
        return Customer.find_by(id: @discovery_business.customer_id, organization_id: @organization.id)
      end

      normalized_name = @discovery_business.business_name.to_s.strip.downcase
      return nil if normalized_name.blank?

      Customer.where(organization_id: @organization.id, archived: false)
              .where("LOWER(name) = ?", normalized_name)
              .first
    end

    def ensure_registered_agent_contact!(customer)
      return if PotentialCustomerFields.registered_agent_full_name(@discovery_business).blank?
      return if customer.contacts.exists?

      PotentialCustomerFields.sync_registered_agent_contact!(
        @discovery_business,
        customer,
        organization: @organization
      )
    end
  end
end
