# frozen_string_literal: true

module Outreach
  module Sms
    class Compliance
      OPT_OUT_KEYWORDS = %w[STOP STOPALL UNSUBSCRIBE CANCEL END QUIT].freeze
      OPT_IN_KEYWORDS = %w[YES START UNSTOP].freeze

      def self.opted_out?(customer)
        return false unless customer

        customer.sms_opted_out?
      end

      def self.can_send?(customer:, phone: nil, dev_mode: false)
        return true if dev_mode
        return false if opted_out?(customer)
        return false if customer&.organization && phone.present? &&
                        OptListService.phone_opted_out?(organization: customer.organization, phone: phone)

        true
      end

      def self.opt_out!(customer:, note: nil, source: nil, phone: nil)
        return unless customer

        customer.update!(
          sms_opt_in: false,
          sms_opt_out_at: Time.current,
          sms_opt_out_source: source.presence || customer.sms_opt_out_source,
          sms_opt_out_note: note.presence || customer.sms_opt_out_note
        )

        normalized = PhoneNumber.normalize(phone) || PhoneNumber.for_customer(customer)
        OptListService.register_blacklist!(organization: customer.organization, phone: normalized) if normalized.present?
      end

      def self.opt_in!(customer:, phone: nil, source: nil)
        return unless customer

        customer.update!(
          sms_opt_in: true,
          sms_opt_out_at: nil,
          sms_opt_out_note: nil,
          sms_opt_out_source: nil,
          sms_opt_in_source: source.presence || customer.sms_opt_in_source
        )

        normalized = PhoneNumber.normalize(phone) || PhoneNumber.for_customer(customer)
        OptListService.register_whitelist!(organization: customer.organization, phone: normalized) if normalized.present?
      end

      def self.keyword_opt_out?(body)
        OPT_OUT_KEYWORDS.include?(body.to_s.strip.upcase)
      end

      def self.keyword_opt_in?(body)
        OPT_IN_KEYWORDS.include?(body.to_s.strip.upcase)
      end
    end
  end
end
