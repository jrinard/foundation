# frozen_string_literal: true

module Outreach
  module Sms
    class SendMessage
      Result = Struct.new(:enrollment, :message, :error, keyword_init: true) do
        def success?
          error.blank?
        end
      end

      def self.call(enrollment:, body:, recipient_key: nil, user: Current.user, dev_mode: false)
        new(
          enrollment: enrollment,
          body: body,
          recipient_key: recipient_key,
          user: user,
          dev_mode: dev_mode
        ).call
      end

      def initialize(enrollment:, body:, recipient_key:, user:, dev_mode:)
        @enrollment = enrollment
        @body = body.to_s.strip
        @recipient_key = recipient_key
        @user = user
        @dev_mode = dev_mode
        @customer = enrollment.customer
        @recipient = nil
      end

      def call
        return Result.new(enrollment: @enrollment, message: nil, error: "Enrollment is paused.") if @enrollment.paused?
        return Result.new(enrollment: @enrollment, message: nil, error: "Message can't be blank.") if @body.blank?
        return Result.new(enrollment: @enrollment, message: nil, error: "Not on an SMS step.") unless sms_step?

        @recipient = RecipientOptions.find(customer: @customer, key: @recipient_key)

        unless @dev_mode
          unless live_messaging_enabled?
            return Result.new(
              enrollment: @enrollment,
              message: nil,
              error: "Messaging is disabled. Turn on Text Message Sending in Settings → Outreach → Text Messages."
            )
          end

          unless @recipient&.phone_normalized.present?
            return Result.new(enrollment: @enrollment, message: nil, error: "Add a phone number before sending.")
          end
        end

        unless Compliance.can_send?(customer: @customer, phone: @recipient&.phone_normalized, dev_mode: @dev_mode)
          return Result.new(enrollment: @enrollment, message: nil, error: "This prospect has opted out of SMS.")
        end

        @body = TextTemplates.append_opt_out_footer(@body) if first_outreach_send?

        message = nil

        ActiveRecord::Base.transaction do
          message = OutreachTextMessage.create!(
            organization: @enrollment.organization,
            outreach_enrollment: @enrollment,
            customer: @customer,
            user: @user,
            direction: OutreachTextMessage::DIRECTION_OUTBOUND,
            body: @body,
            phone_number: @recipient&.phone_normalized,
            status: OutreachTextMessage::STATUS_RECORDED,
            simulated: @dev_mode
          )

          log_activity!(message)
          apply_status!
        end

        delivery_error = deliver!(message)
        if delivery_error.present?
          return Result.new(enrollment: @enrollment.reload, message: message, error: delivery_error)
        end

        Result.new(enrollment: @enrollment.reload, message: message, error: nil)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(enrollment: @enrollment, message: nil, error: e.record.errors.full_messages.to_sentence)
      end

      private

      def sms_step?
        @enrollment.current_step_type == Outreach::PlanStepTypes::SEND_SMS
      end

      def thread_messages
        OutreachTextMessage.for_thread(enrollment: @enrollment)
      end

      def follow_up_mode?
        thread_messages.inbound.exists?
      end

      def apply_status!
        if follow_up_mode?
          @enrollment.update!(status: OutreachEnrollment::STATUS_CONVERSATION)
        elsif @enrollment.status == OutreachEnrollment::STATUS_READY
          @enrollment.update!(status: OutreachEnrollment::STATUS_WAITING)
        else
          @enrollment.update!(status: OutreachEnrollment::STATUS_WAITING)
        end
      end

      def deliver!(message)
        return nil if @dev_mode

        result = DeliverOutbound.call(message: message)
        return nil if result.skipped || result.delivered

        result.error
      end

      def live_messaging_enabled?
        OutreachSmsChannel.integration_for(@enrollment.organization)&.ready_to_send?
      end

      def log_activity!(message)
        step = @enrollment.current_step
        first = first_outbound?(message)
        OutreachActivity.create!(
          organization: @enrollment.organization,
          outreach_enrollment: @enrollment,
          user: @user,
          activity_type: first ? "sms_first_reachout" : "sms_sent",
          summary: send_activity_summary(step, first: first),
          metadata: {
            message_body: message.body,
            phone_number: message.phone_number,
            sms_recipient_key: @recipient&.key,
            outreach_text_message_id: message.id,
            first_reachout: first,
            step_position: step&.dig("position"),
            step_name: step&.dig("name"),
            step_type: step&.dig("step_type")
          }.compact
        )
      end

      def send_activity_summary(step, first:)
        label = step&.dig("name") || "SMS"
        first ? "First reachout — #{label}" : "Text sent — #{label}"
      end

      def first_outbound?(message)
        thread_messages.outbound.where.not(id: message.id).none?
      end

      def first_outreach_send?
        thread_messages.outbound.none?
      end
    end
  end
end
