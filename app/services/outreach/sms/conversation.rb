# frozen_string_literal: true

module Outreach
  module Sms
    class Conversation
      Message = Struct.new(:direction, :body, :occurred_at, :simulated, :status, keyword_init: true) do
        def outbound?
          direction == :outbound
        end

        def inbound?
          direction == :inbound
        end

        def failed?
          status == OutreachTextMessage::STATUS_FAILED
        end
      end

      def self.for(enrollment:)
        new(enrollment: enrollment).messages
      end

      def self.for_phone(organization:, phone_number:)
        normalized = PhoneNumber.normalize(phone_number)
        return [] if normalized.blank?

        OutreachTextMessage
          .where(organization: organization, phone_number: normalized)
          .chronological
          .map { |record| message_from_record(record) }
      end

      def initialize(enrollment:)
        @enrollment = enrollment
      end

      def messages
        OutreachTextMessage
          .for_thread(enrollment: @enrollment)
          .map { |record| message_from_record(record) }
      end

      def awaiting_simulated_reply?
        last_message = OutreachTextMessage.for_thread(enrollment: @enrollment).last
        last_message&.outbound?
      end

      def follow_up_mode?
        OutreachTextMessage
          .for_thread(enrollment: @enrollment)
          .where(direction: OutreachTextMessage::DIRECTION_INBOUND)
          .exists?
      end

      private

      def message_from_record(record)
        Message.new(
          direction: record.outbound? ? :outbound : :inbound,
          body: record.body,
          occurred_at: record.created_at,
          simulated: record.simulated?,
          status: record.status
        )
      end
    end
  end
end
