# frozen_string_literal: true

module Outreach
  module Sms
    module PhoneNumber
      module_function

      def normalize(raw)
        digits = raw.to_s.gsub(/\D/, "")
        return nil if digits.blank?

        digits = "1#{digits}" if digits.length == 10
        "+#{digits}"
      end

      def for_customer(customer)
        RecipientOptions.find(customer: customer, key: "customer")&.phone_normalized ||
          RecipientOptions.for(customer: customer).first&.phone_normalized
      end
    end
  end
end
