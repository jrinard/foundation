# frozen_string_literal: true

module Discovery
  class SyncPotentialFromDiscovery
    Result = Struct.new(:success, :customer, :error, keyword_init: true)

    def self.call(discovery_business:)
      new(discovery_business: discovery_business).call
    end

    def initialize(discovery_business:)
      @discovery_business = discovery_business
      @organization = discovery_business.organization
    end

    def call
      customer = linked_customer
      return failure("No linked prospect to sync.") unless customer

      ActiveRecord::Base.transaction do
        customer.update!(PotentialCustomerFields.sync_attributes(@discovery_business))
        PotentialCustomerFields.sync_registered_agent_contact!(
          @discovery_business,
          customer,
          organization: @organization
        )
      end

      Result.new(success: true, customer: customer, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def linked_customer
      customer = @discovery_business.customer
      return nil unless customer
      return nil unless customer.organization_id == @organization.id

      customer
    end

    def failure(message)
      Result.new(success: false, customer: nil, error: message)
    end
  end
end
