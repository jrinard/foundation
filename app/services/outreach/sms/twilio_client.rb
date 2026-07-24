# frozen_string_literal: true

module Outreach
  module Sms
    class TwilioClient
      Result = Struct.new(:success, :sid, :error, keyword_init: true) do
        def success?
          success == true
        end
      end

      def initialize(channel)
        @channel = channel
      end

      def send_message(to:, body:)
        unless @channel&.ready_to_send?
          return Result.new(success: false, sid: nil, error: "Twilio channel is not configured.")
        end

        unless twilio_gem_available?
          return Result.new(success: false, sid: nil, error: "Twilio gem not loaded.")
        end

        client = ::Twilio::REST::Client.new(@channel.effective_account_sid, @channel.effective_auth_token)
        message = client.messages.create(
          from: PhoneNumber.normalize(@channel.effective_from_number) || @channel.effective_from_number,
          to: to,
          body: body
        )

        Result.new(success: true, sid: message.sid, error: nil)
      rescue StandardError => e
        Result.new(success: false, sid: nil, error: e.message)
      end

      private

      def twilio_gem_available?
        defined?(::Twilio::REST::Client)
      end
    end
  end
end
