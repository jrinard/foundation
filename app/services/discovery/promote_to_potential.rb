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

        customer ||= Customer.create!(customer_attributes)
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

    def customer_attributes
      address_fields = parse_office_address(@discovery_business.office_address)

      {
        organization: @organization,
        name: @discovery_business.business_name,
        phone: @discovery_business.phone,
        email: @discovery_business.email,
        address: address_fields[:address],
        city: address_fields[:city].presence || @discovery_business.city,
        state: address_fields[:state].presence || "WA",
        zip: address_fields[:zip],
        active: false,
        archived: false,
        onBoard: "The List",
        list_id: nil,
        extra_notes: discovery_extra_notes
      }
    end

    def discovery_extra_notes
      parts = ["WA SOS Discovery"]
      parts << "UBI #{@discovery_business.external_id}" if @discovery_business.external_id.present?
      parts.join(" · ")
    end

    def parse_office_address(office_address)
      return { address: nil, city: nil, state: nil, zip: nil } if office_address.blank?

      parts = office_address.split(",").map(&:strip).reject(&:blank?)
      state_index = parts.index { |part| part.match?(/\AWA\b/i) }

      return { address: office_address, city: nil, state: "WA", zip: nil } unless state_index

      street_parts = parts[0...state_index]
      city = state_index.positive? ? parts[state_index - 1] : nil
      zip_part = parts[state_index + 1]
      zip = zip_part&.match(/\d{5}/)&.to_s

      {
        address: street_parts.join(", ").presence,
        city: city,
        state: "WA",
        zip: zip
      }
    end
  end
end
