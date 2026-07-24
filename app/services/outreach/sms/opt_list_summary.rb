# frozen_string_literal: true

module Outreach
  module Sms
    class OptListSummary
      Entry = Struct.new(:customer, :customer_id, :phone, :phone_display, :opted_at, :note, :path, keyword_init: true)

      include Rails.application.routes.url_helpers

      def self.call(organization:)
        new(organization: organization).call
      end

      def initialize(organization:)
        @organization = organization
        @channel = OutreachSmsChannel.integration_for(organization)
      end

      def call
        opted_out_customers = load_opted_out_customers
        opted_in_customers = load_opted_in_customers
        opted_out_phones = opted_out_customers.filter_map(&:phone)
        opted_in_phones = opted_in_customers.filter_map(&:phone)
        black_only = orphan_phones(@channel.numbers_black_list, opted_out_phones)
        white_only = orphan_phones(@channel.numbers_white_list, opted_in_phones)

        {
          opted_out: opted_out_customers + black_only,
          opted_in: opted_in_customers + white_only,
          opted_out_count: opted_out_customers.size + black_only.size,
          opted_in_count: opted_in_customers.size + white_only.size
        }
      end

      private

      def load_opted_out_customers
        Customer
          .where(organization: @organization)
          .where("sms_opt_out_at IS NOT NULL OR sms_opt_in = ?", false)
          .order(sms_opt_out_at: :desc, name: :asc)
          .map { |customer| entry_for(customer, list: :out) }
      end

      def load_opted_in_customers
        Customer
          .where(organization: @organization, sms_opt_in: true)
          .where(sms_opt_out_at: nil)
          .order(name: :asc)
          .map { |customer| entry_for(customer, list: :in) }
      end

      def entry_for(customer, list:)
        phone_option = RecipientOptions.for(customer: customer).first
        raw_phone = phone_option&.phone_display.presence || customer.phone.presence || phone_option&.phone_normalized
        Entry.new(
          customer: customer,
          customer_id: customer.id,
          phone: phone_option&.phone_normalized,
          phone_display: raw_phone,
          opted_at: list == :out ? customer.sms_opt_out_at : nil,
          note: customer.sms_opt_out_note,
          path: customer_work_path(customer)
        )
      end

      def orphan_phones(list, covered_phones)
        Array(list).filter_map do |phone|
          normalized = PhoneNumber.normalize(phone)
          next if normalized.blank?
          next if covered_phones.include?(normalized)

          Entry.new(
            customer: nil,
            customer_id: nil,
            phone: normalized,
            phone_display: normalized,
            opted_at: nil,
            note: "On org list — no matching customer",
            path: nil
          )
        end
      end

      def customer_work_path(customer)
        if customer.onBoard == "The List"
          potentials_path(id: customer.id)
        else
          customers_path(id: customer.id)
        end
      end
    end
  end
end
