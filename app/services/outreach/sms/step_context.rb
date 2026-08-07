# frozen_string_literal: true

module Outreach
  module Sms
    class StepContext
      FROM_NUMBER_REQUIRED_MESSAGE =
        "Set this org's from number in Settings → Outreach → Text Messages before sending. " \
        "Each org needs its own phone number — prospects reply to that number and inbound SMS routes by it."

      attr_reader :enrollment, :composer, :conversation

      def initialize(enrollment:, sms_recipient_key: nil, dev_mode: false, dev_tools_available: false)
        @enrollment = enrollment
        @sms_recipient_key = sms_recipient_key
        @dev_mode = dev_mode
        @dev_tools_available = dev_tools_available
        @composer = Composer.new(
          customer: enrollment.customer,
          user: Current.user,
          recipient_key: @sms_recipient_key
        )
        @conversation = Conversation.new(enrollment: enrollment)
      end

      def partial_locals
        template_set = follow_up_mode? ? TextTemplates::RESPONSE : TextTemplates::OPENING
        reply_intent = last_reply_intent if follow_up_mode?
        message_body = composer.draft_body(set: template_set, reply_intent: reply_intent)

        {
          enrollment: enrollment,
          composer: composer,
          phone: composer.phone,
          phone_present: composer.phone_present?,
          recipient_options: composer.recipient_options,
          selected_recipient_key: composer.selected_recipient_key,
          message_body: message_body,
          text_templates: composer.text_templates(set: template_set),
          response_template_groups: follow_up_mode? ? composer.response_template_groups : [],
          response_template_columns: follow_up_mode? ? composer.response_template_columns : {},
          default_text_template_key: composer.default_text_template_key(set: template_set, reply_intent: reply_intent),
          follow_up_mode: follow_up_mode?,
          dev_mode: @dev_mode,
          dev_tools_available: @dev_tools_available,
          sms_opted_out: Compliance.opted_out?(enrollment.customer),
          live_messaging_enabled: live_messaging_enabled?,
          org_from_number_configured: org_from_number_configured?,
          from_number_required_message: FROM_NUMBER_REQUIRED_MESSAGE,
          send_enabled: send_enabled?,
          send_disabled_reason: send_disabled_reason,
          awaiting_simulated_reply: @dev_tools_available && @dev_mode && awaiting_simulated_reply?,
          simulate_reply_groups: SimulateInboundReply::REPLY_GROUPS,
          conversation_messages: conversation.messages,
          poll_inbound_count: inbound_message_scope.count,
          poll_last_inbound_id: inbound_message_scope.maximum(:id),
          sms_polling_enabled: sms_channel&.enrollment_sms_polling_enabled?
        }
      end

      private

      def inbound_message_scope
        OutreachTextMessage.for_thread(enrollment: enrollment).inbound
      end

      def live_messaging_enabled?
        sms_channel&.ready_to_send?
      end

      def org_from_number_configured?
        sms_channel&.org_from_number_configured?
      end

      def sms_channel
        @sms_channel ||= OutreachSmsChannel.integration_for(enrollment.organization)
      end

      def send_disabled_reason
        return nil if @dev_mode
        return "Prospect opted out" if Compliance.opted_out?(enrollment.customer)
        return FROM_NUMBER_REQUIRED_MESSAGE unless org_from_number_configured?
        return "Messaging disabled — turn on Text Message Sending in Settings → Outreach → Text Messages" unless live_messaging_enabled?
        return "Phone is missing — add one on the prospect profile before sending." unless composer.phone_present?

        nil
      end

      def send_enabled?
        send_disabled_reason.nil?
      end

      def follow_up_mode?
        conversation.follow_up_mode?
      end

      def awaiting_simulated_reply?
        conversation.awaiting_simulated_reply?
      end

      def last_reply_intent
        activity = enrollment.activities
          .where(activity_type: "sms_replied")
          .order(created_at: :desc)
          .first

        activity&.metadata&.dig("reply_type")
      end
    end
  end
end
