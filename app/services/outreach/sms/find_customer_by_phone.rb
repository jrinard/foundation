# frozen_string_literal: true

module Outreach
  module Sms
    class FindCustomerByPhone
      def self.call(organization:, phone:)
        new(organization: organization, phone: phone).call
      end

      def initialize(organization:, phone:)
        @organization = organization
        @normalized = PhoneNumber.normalize(phone)
        @digits = @normalized.to_s.gsub(/\D/, "").last(10)
      end

      def call
        return nil if @digits.blank? || @digits.length != 10

        from_recent_message || from_customer_phone || from_contact_phone
      end

      private

      def from_recent_message
        OutreachTextMessage
          .unscoped_by_organization
          .where(organization: @organization, phone_number: @normalized)
          .order(created_at: :desc)
          .first
          &.customer
      end

      def from_customer_phone
        Customer
          .unscoped_by_organization
          .where(organization: @organization)
          .where("RIGHT(REGEXP_REPLACE(COALESCE(phone, ''), '[^0-9]', '', 'g'), 10) = ?", @digits)
          .first
      end

      def from_contact_phone
        Contact
          .joins(:customer)
          .where(customers: { organization_id: @organization.id })
          .where(
            "RIGHT(REGEXP_REPLACE(COALESCE(contacts.phone, ''), '[^0-9]', '', 'g'), 10) = :digits OR " \
            "RIGHT(REGEXP_REPLACE(COALESCE(contacts.phone2, ''), '[^0-9]', '', 'g'), 10) = :digits",
            digits: @digits
          )
          .first
          &.customer
      end
    end
  end
end
