# frozen_string_literal: true

module Discovery
  module PotentialCustomerFields
    module_function

    def customer_attributes(discovery_business, organization: discovery_business.organization)
      address_fields = parse_office_address(discovery_business.office_address)

      {
        organization: organization,
        name: discovery_business.business_name,
        phone: discovery_business.phone,
        email: discovery_business.email,
        address: address_fields[:address],
        city: address_fields[:city].presence || discovery_business.city,
        state: address_fields[:state].presence || "WA",
        zip: address_fields[:zip],
        active: false,
        archived: false,
        onBoard: "The List",
        list_id: nil,
        extra_notes: discovery_extra_notes(discovery_business)
      }
    end

    def sync_attributes(discovery_business)
      customer_attributes(discovery_business).slice(:name, :phone, :email, :address, :city, :state, :zip)
    end

    def sync_registered_agent_contact!(discovery_business, customer, organization: discovery_business.organization)
      full_name = registered_agent_full_name(discovery_business)
      return if full_name.blank?

      firstname, lastname = split_person_name(full_name)
      contact_attrs = {
        firstname: firstname,
        lastname: lastname,
        phone: discovery_business.phone.presence || customer.phone,
        email: discovery_business.email.presence || customer.email
      }

      contact = customer.contacts.find_by(position: "Registered Agent")
      if contact
        contact.update!(contact_attrs)
      else
        customer.contacts.create!(
          contact_attrs.merge(organization: organization, position: "Registered Agent")
        )
      end
    end

    def registered_agent_full_name(discovery_business)
      full_name = discovery_business.registered_agent_name.to_s.strip
      full_name = discovery_business.display_registered_agent_name.to_s.strip if full_name.blank?
      full_name.presence
    end

    def discovery_extra_notes(discovery_business)
      parts = ["WA SOS Discovery"]
      parts << "UBI #{discovery_business.external_id}" if discovery_business.external_id.present?
      parts.join(" · ")
    end

    def split_person_name(full_name)
      parts = full_name.split(/\s+/, 2)
      [parts[0], parts[1].to_s]
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
