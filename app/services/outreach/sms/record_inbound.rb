# frozen_string_literal: true

module Outreach
  module Sms
    class RecordInbound
      Result = Struct.new(:enrollment, :message, :error, keyword_init: true) do
        def success?
          error.blank?
        end
      end

      def self.call(enrollment:, body:, phone_number:, external_id: nil, simulated: false, reply_type: nil)
        new(
          enrollment: enrollment,
          body: body,
          phone_number: phone_number,
          external_id: external_id,
          simulated: simulated,
          reply_type: reply_type
        ).call
      end

      def initialize(enrollment:, body:, phone_number:, external_id:, simulated:, reply_type:)
        @enrollment = enrollment
        @body = body.to_s.strip
        @phone_number = phone_number
        @external_id = external_id
        @simulated = simulated
        @reply_type = reply_type
        @customer = enrollment.customer
      end

      def call
        return Result.new(enrollment: @enrollment, message: nil, error: "Message can't be blank.") if @body.blank?

        message = nil

        ActiveRecord::Base.transaction do
          message = OutreachTextMessage.create!(
            organization: @enrollment.organization,
            outreach_enrollment: @enrollment,
            customer: @customer,
            user: nil,
            direction: OutreachTextMessage::DIRECTION_INBOUND,
            body: @body,
            phone_number: @phone_number,
            status: OutreachTextMessage::STATUS_RECORDED,
            simulated: @simulated,
            external_id: @external_id
          )

          log_activity!(message)
          @enrollment.update!(status: OutreachEnrollment::STATUS_CONVERSATION)
        end

        Result.new(enrollment: @enrollment.reload, message: message, error: nil)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(enrollment: @enrollment, message: nil, error: e.record.errors.full_messages.to_sentence)
      end

      private

      def log_activity!(message)
        step = @enrollment.current_step
        OutreachActivity.create!(
          organization: @enrollment.organization,
          outreach_enrollment: @enrollment,
          user: nil,
          activity_type: "sms_replied",
          summary: "Text replied — #{step&.dig('name') || 'SMS'}",
          metadata: {
            reply_body: message.body,
            phone_number: message.phone_number,
            outreach_text_message_id: message.id,
            simulated: @simulated,
            reply_type: @reply_type,
            customer_name: @customer.name,
            step_position: step&.dig("position"),
            step_name: step&.dig("name"),
            step_type: step&.dig("step_type")
          }.compact
        )
      end
    end
  end
end
