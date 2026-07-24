# frozen_string_literal: true

module Outreach
  module Sms
    class DeliverOutbound
      Result = Struct.new(:delivered, :skipped, :error, keyword_init: true) do
        def success?
          error.blank?
        end
      end

      def self.call(message:)
        new(message: message).call
      end

      def initialize(message:)
        @message = message
        @organization = message.organization
      end

      def call
        channel = OutreachSmsChannel.integration_for(@organization)
        unless channel&.ready_to_send?
          return Result.new(delivered: false, skipped: true, error: nil)
        end

        response = TwilioClient.new(channel).send_message(
          to: @message.phone_number,
          body: @message.body
        )

        if response.success?
          @message.update!(
            status: OutreachTextMessage::STATUS_SENT,
            external_id: response.sid
          )
          Rails.logger.info("=== Message Successfully Sent to #{@message.phone_number}")
          Result.new(delivered: true, skipped: false, error: nil)
        else
          @message.update!(status: OutreachTextMessage::STATUS_FAILED)
          Result.new(delivered: false, skipped: false, error: response.error)
        end
      end
    end
  end
end
