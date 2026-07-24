# frozen_string_literal: true

module Outreach
  module Sms
    class OptListService
      def self.register_blacklist!(organization:, phone:)
        new(organization: organization, phone: phone).register_blacklist!
      end

      def self.register_whitelist!(organization:, phone:)
        new(organization: organization, phone: phone).register_whitelist!
      end

      def self.phone_opted_out?(organization:, phone:)
        normalized = PhoneNumber.normalize(phone)
        return false if normalized.blank?

        channel = OutreachSmsChannel.integration_for(organization)
        blacklisted = Array(channel.numbers_black_list).any? do |entry|
          PhoneNumber.normalize(entry) == normalized
        end
        return true if blacklisted

        customer = FindCustomerByPhone.call(organization: organization, phone: normalized)
        customer.present? && Compliance.opted_out?(customer)
      end

      def self.add_to_blacklist(organization:, phone:, customer: nil)
        register_blacklist!(organization: organization, phone: phone)
        Compliance.opt_out!(customer: customer, source: "SMS blacklist", note: phone) if customer
      end

      def self.add_to_whitelist(organization:, phone:, customer: nil)
        register_whitelist!(organization: organization, phone: phone)
        Compliance.opt_in!(customer: customer) if customer
      end

      def initialize(organization:, phone:)
        @organization = organization
        @phone = PhoneNumber.normalize(phone)
        @channel = OutreachSmsChannel.integration_for(organization)
      end

      def register_blacklist!
        return if @phone.blank?

        black_list = Array(@channel.numbers_black_list)
        white_list = Array(@channel.numbers_white_list)
        black_list << @phone unless black_list.include?(@phone)
        white_list -= [@phone]

        @channel.update!(numbers_black_list: black_list.uniq, numbers_white_list: white_list.uniq)
      end

      def register_whitelist!
        return if @phone.blank?

        white_list = Array(@channel.numbers_white_list)
        black_list = Array(@channel.numbers_black_list)
        white_list << @phone unless white_list.include?(@phone)
        black_list -= [@phone]

        @channel.update!(numbers_white_list: white_list.uniq, numbers_black_list: black_list.uniq)
      end
    end
  end
end
