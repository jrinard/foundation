# frozen_string_literal: true

module Outreach
  module Sms
    class ProcessInboundWebhook
      Result = Struct.new(:status, :twiml, :error, keyword_init: true)

      def self.call(from:, to:, body:, message_sid: nil)
        new(from: from, to: to, body: body, message_sid: message_sid).call
      end

      def initialize(from:, to:, body:, message_sid:)
        @from = from
        @to = to
        @body = body.to_s.strip
        @message_sid = message_sid
      end

      def call
        channel = OutreachSmsChannel.find_active_by_from_number(@to)
        unless channel
          Rails.logger.info(
            "Outreach Twilio inbound ignored — no active channel for To=#{@to.inspect} " \
            "(set From Number in Settings → Outreach → Text Messages)"
          )
          return Result.new(status: :ignored, twiml: nil, error: nil)
        end

        organization = channel.organization
        normalized_from = PhoneNumber.normalize(@from)
        return Result.new(status: :invalid, twiml: nil, error: "Invalid sender phone.") if normalized_from.blank?

        if Compliance.keyword_opt_out?(@body)
          customer = FindCustomerByPhone.call(organization: organization, phone: normalized_from)
          Compliance.opt_out!(
            customer: customer,
            source: "Twilio STOP",
            note: @body,
            phone: normalized_from
          )
          record_inbound_if_possible(organization: organization, phone: normalized_from)
          return Result.new(status: :opt_out, twiml: channel.opt_out_twiml, error: nil)
        end

        if Compliance.keyword_opt_in?(@body)
          customer = FindCustomerByPhone.call(organization: organization, phone: normalized_from)
          Compliance.opt_in!(customer: customer, phone: normalized_from, source: "Twilio YES")
          record_inbound_if_possible(organization: organization, phone: normalized_from)
          return Result.new(status: :opt_in, twiml: channel.opt_in_twiml, error: nil)
        end

        if Compliance.keyword_help?(@body)
          record_inbound_if_possible(organization: organization, phone: normalized_from)
          return Result.new(status: :help, twiml: channel.help_twiml, error: nil)
        end

        enrollment = FindEnrollmentByPhone.call(organization: organization, phone: normalized_from)
        unless enrollment
          Rails.logger.info(
            "Outreach Twilio inbound unmatched — From=#{normalized_from.inspect} org=#{organization.id} " \
            "(no open enrollment with recent outbound to this number)"
          )
          return Result.new(status: :unmatched, twiml: nil, error: nil)
        end

        RecordInbound.call(
          enrollment: enrollment,
          body: @body,
          phone_number: normalized_from,
          external_id: @message_sid,
          simulated: false
        )

        Result.new(status: :recorded, twiml: nil, error: nil)
      rescue StandardError => e
        Rails.logger.error("Outreach Twilio inbound error: #{e.class} #{e.message}")
        Result.new(status: :error, twiml: nil, error: e.message)
      end

      private

      def record_inbound_if_possible(organization:, phone:)
        enrollment = FindEnrollmentByPhone.call(organization: organization, phone: phone)
        return unless enrollment

        RecordInbound.call(
          enrollment: enrollment,
          body: @body,
          phone_number: phone,
          external_id: @message_sid,
          simulated: false
        )
      end
    end
  end
end
