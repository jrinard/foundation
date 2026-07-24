# frozen_string_literal: true

module Outreach
  module Sms
    class SimulateInboundReply
      REPLY_TYPES = {
        "yes" => "Yes — I'd love to hear more.",
        "maybe" => "Maybe — not sure yet.",
        "not_right_now" => "Not right now, thanks.",
        "have_someone" => "We already have someone.",
        "how_get_number" => "How did you get my number?",
        "who_are_you" => "Who are you?",
        "online_presence" => 'What do you mean by "online presence?"',
        "pricing" => "How much do you charge?",
        "no_thanks" => "No thanks."
      }.freeze

      REPLY_GROUPS = [
        { intent: "positive", label: "Positive / timing", types: %w[yes maybe not_right_now have_someone] },
        { intent: "questions", label: "Questions", types: %w[how_get_number who_are_you online_presence pricing] },
        { intent: "close", label: "Close", types: %w[no_thanks] }
      ].freeze

      Result = Struct.new(:enrollment, :message, :error, keyword_init: true) do
        def success?
          error.blank?
        end
      end

      def self.call(enrollment:, reply_type: "yes", recipient_key: nil, body: nil, user: Current.user)
        new(
          enrollment: enrollment,
          reply_type: reply_type,
          recipient_key: recipient_key,
          body: body,
          user: user
        ).call
      end

      def self.label_for(reply_type)
        REPLY_TYPES.fetch(reply_type.to_s) { reply_type.to_s.humanize }
      end

      def self.simulate_button_label(reply_type)
        {
          "yes" => "Yes",
          "maybe" => "Maybe",
          "not_right_now" => "Not right now",
          "have_someone" => "Have someone",
          "how_get_number" => "How got #?",
          "who_are_you" => "Who are you?",
          "online_presence" => "Online presence?",
          "pricing" => "Pricing?",
          "no_thanks" => "No thanks"
        }.fetch(reply_type.to_s, reply_type.to_s.humanize)
      end

      def initialize(enrollment:, reply_type:, recipient_key:, body:, user:)
        @enrollment = enrollment
        @reply_type = reply_type.to_s
        @recipient_key = recipient_key
        @body = body.to_s.strip.presence
        @user = user
        @customer = enrollment.customer
      end

      def call
        return Result.new(enrollment: @enrollment, message: nil, error: "Enrollment is paused.") if @enrollment.paused?
        return Result.new(enrollment: @enrollment, message: nil, error: "Send a message first.") unless outbound_messages.exists?
        return Result.new(enrollment: @enrollment, message: nil, error: "Waiting on their reply — simulate after your last outbound message.") unless awaiting_reply?

        reply_body = @body || REPLY_TYPES.fetch(@reply_type) { REPLY_TYPES["yes"] }
        recipient = resolved_recipient

        message = nil

        ActiveRecord::Base.transaction do
          message = OutreachTextMessage.create!(
            organization: @enrollment.organization,
            outreach_enrollment: @enrollment,
            customer: @customer,
            user: @user,
            direction: OutreachTextMessage::DIRECTION_INBOUND,
            body: reply_body,
            phone_number: recipient&.phone_normalized,
            status: OutreachTextMessage::STATUS_RECORDED,
            simulated: true
          )

          log_activity!(message)
          @enrollment.update!(status: OutreachEnrollment::STATUS_CONVERSATION)
        end

        Result.new(enrollment: @enrollment.reload, message: message, error: nil)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(enrollment: @enrollment, message: nil, error: e.record.errors.full_messages.to_sentence)
      end

      private

      def outbound_messages
        OutreachTextMessage.for_thread(enrollment: @enrollment).where(direction: OutreachTextMessage::DIRECTION_OUTBOUND)
      end

      def awaiting_reply?
        last_message = OutreachTextMessage.for_thread(enrollment: @enrollment).last
        last_message&.outbound?
      end

      def resolved_recipient
        last_outbound = OutreachTextMessage.for_thread(enrollment: @enrollment).outbound.order(created_at: :desc).first
        if last_outbound&.phone_number.present?
          return RecipientOptions.new(customer: @customer).options.find do |option|
            option.phone_normalized == last_outbound.phone_number
          end
        end

        RecipientOptions.find(customer: @customer, key: @recipient_key)
      end

      def log_activity!(message)
        step = @enrollment.current_step
        OutreachActivity.create!(
          organization: @enrollment.organization,
          outreach_enrollment: @enrollment,
          user: @user,
          activity_type: "sms_replied",
          summary: "Text replied — #{step&.dig('name') || 'SMS'}",
          metadata: {
            reply_body: message.body,
            phone_number: message.phone_number,
            outreach_text_message_id: message.id,
            simulated: true,
            reply_type: @reply_type,
            sms_recipient_key: resolved_recipient&.key,
            step_position: step&.dig("position"),
            step_name: step&.dig("name"),
            step_type: step&.dig("step_type")
          }.compact
        )
      end
    end
  end
end
