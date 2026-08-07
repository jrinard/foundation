# frozen_string_literal: true

module Outreach
  module Sms
    class RecipientOptions
      Option = Struct.new(:key, :label, :phone_display, :phone_raw, :phone_normalized, keyword_init: true)

      def self.for(customer:)
        new(customer: customer).options
      end

      def self.find(customer:, key:)
        new(customer: customer).find(key)
      end

      def self.default_key(customer:)
        new(customer: customer).default_key
      end

      def initialize(customer:)
        @customer = customer
        @discovery = customer.linked_discovery_business
      end

      def options
        entries = []
        add_phone_option(
          entries,
          key: "customer",
          label: customer_label,
          raw: @customer.phone
        )

        @customer.contacts.each do |contact|
          add_phone_option(
            entries,
            key: "contact_#{contact.id}_phone",
            label: contact_label(contact, contact.phone),
            raw: contact.phone
          )
          add_phone_option(
            entries,
            key: "contact_#{contact.id}_phone2",
            label: contact_label(contact, contact.phone2, secondary: true),
            raw: contact.phone2
          )
        end

        add_phone_option(
          entries,
          key: "discovery",
          label: discovery_label,
          raw: @discovery&.phone
        )

        entries
      end

      def find(key)
        options.find { |option| option.key == key.to_s } || options.first
      end

      def default_key
        options.first&.key
      end

      private

      def add_phone_option(entries, key:, label:, raw:)
        raw = raw.to_s.strip
        return if raw.blank?

        normalized = PhoneNumber.normalize(raw)
        return if normalized.blank?

        entries << Option.new(
          key: key,
          label: label,
          phone_display: raw,
          phone_raw: raw,
          phone_normalized: normalized
        )
      end

      def customer_label
        @customer.name.presence || "Business"
      end

      def contact_label(contact, _phone, secondary: false)
        name = [contact.firstname, contact.lastname].map { |part| part.to_s.strip.presence }.compact.join(" ")
        name = "Contact" if name.blank?
        secondary ? "#{name} (alt)" : name
      end

      def discovery_label
        "Discovery listing"
      end
    end
  end
end
