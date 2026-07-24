# frozen_string_literal: true

module Outreach
  module Sms
    class FindEnrollmentByPhone
      def self.call(organization:, phone:)
        new(organization: organization, phone: phone).call
      end

      def initialize(organization:, phone:)
        @organization = organization
        @normalized = PhoneNumber.normalize(phone)
      end

      def call
        return nil if @normalized.blank?

        from_recent_outbound || from_customer_open_enrollment
      end

      private

      def from_recent_outbound
        OutreachTextMessage
          .unscoped_by_organization
          .where(organization: @organization, phone_number: @normalized, direction: OutreachTextMessage::DIRECTION_OUTBOUND)
          .joins(:outreach_enrollment)
          .merge(OutreachEnrollment.open)
          .order(created_at: :desc)
          .first
          &.outreach_enrollment
      end

      def from_customer_open_enrollment
        customer = FindCustomerByPhone.call(organization: @organization, phone: @normalized)
        return nil unless customer

        OutreachEnrollment
          .unscoped_by_organization
          .where(organization: @organization, customer: customer)
          .open
          .order(enrolled_at: :desc)
          .find { |enrollment| enrollment.current_step_type == Outreach::PlanStepTypes::SEND_SMS }
      end
    end
  end
end
