# frozen_string_literal: true

module Outreach
  class AdvanceStep
    Result = Struct.new(:enrollment, :error, keyword_init: true) do
      def success?
        error.blank?
      end
    end

    def self.call(enrollment:, outcome:, notes: nil, message_body: nil, sms_outcome: nil, force_advance: false, user: Current.user)
      new(
        enrollment: enrollment,
        outcome: outcome,
        notes: notes,
        message_body: message_body,
        sms_outcome: sms_outcome,
        force_advance: force_advance,
        user: user
      ).call
    end

    def initialize(enrollment:, outcome:, notes:, message_body:, sms_outcome:, force_advance:, user:)
      @enrollment = enrollment
      @outcome = outcome.to_s
      @notes = notes
      @message_body = message_body
      @sms_outcome = sms_outcome
      @force_advance = force_advance
      @user = user
    end

    def call
      return Result.new(enrollment: @enrollment, error: "Enrollment is paused.") if @enrollment.paused?

      ActiveRecord::Base.transaction do
        step_being_completed = @enrollment.current_step
        @status_before = @enrollment.status
        apply_status!
        apply_customer_sms_compliance!(step_being_completed)
        @status_after = @enrollment.status
        log_activity!(step_being_completed)
        advance_position!(step_being_completed) unless @outcome.in?(%w[follow_up_later not_interested])
      end

      Result.new(enrollment: @enrollment.reload, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(enrollment: @enrollment, error: e.record.errors.full_messages.to_sentence)
    end

    private

    def apply_status!
      case @outcome
      when "interested"
        @enrollment.update!(status: OutreachEnrollment::STATUS_INTERESTED)
      when "not_interested"
        @enrollment.update!(status: OutreachEnrollment::STATUS_LOST)
      when "follow_up_later"
        @enrollment.update!(status: OutreachEnrollment::STATUS_FOLLOW_UP, paused_at: Time.current)
      when "waiting"
        @enrollment.update!(status: OutreachEnrollment::STATUS_WAITING)
      when "conversation"
        @enrollment.update!(status: OutreachEnrollment::STATUS_CONVERSATION)
      else
        @enrollment.update!(status: OutreachEnrollment::STATUS_CONTACTED) if @enrollment.status == OutreachEnrollment::STATUS_READY
      end
    end

    def advance_position!(step)
      return if @outcome.in?(%w[follow_up_later not_interested])
      return if sms_step?(step) && !@force_advance

      next_position = @enrollment.current_step_position + 1
      if next_position > @enrollment.total_steps
        @enrollment.update!(
          current_step_position: next_position,
          status: OutreachEnrollment::STATUS_COMPLETED
        )
      else
        @enrollment.update!(current_step_position: next_position)
      end
    end

    def log_activity!(step)
      OutreachActivity.create!(
        organization: @enrollment.organization,
        outreach_enrollment: @enrollment,
        user: @user,
        activity_type: activity_type_for(step),
        summary: step_summary(step),
        metadata: activity_metadata(step)
      )
    end

    def activity_type_for(step)
      return "status_changed" if status_change_activity?(step)
      return "sms_replied" if sms_step?(step) && @sms_outcome == "replied"
      return "sms_replied" if sms_step?(step) && @outcome == "conversation"
      return "sms_sent" if sms_step?(step) && @sms_outcome == "sent"
      return "sms_opt_out" if sms_step?(step) && @sms_outcome == "opt_out"

      "step_completed"
    end

    def activity_metadata(step)
      metadata = {
        outcome: @outcome,
        sms_outcome: @sms_outcome,
        notes: @notes,
        message_body: @message_body,
        reply_body: (@sms_outcome == "replied" ? @notes : nil),
        step_position: step&.dig("position"),
        step_name: step&.dig("name"),
        step_type: step&.dig("step_type")
      }

      if status_change_activity?(step)
        metadata.merge!(
          status_before: @status_before,
          status_after: @status_after,
          status_before_label: enrollment_status_label(@status_before),
          status_after_label: enrollment_status_label(@status_after),
          sms_outcome_label: sms_outcome_label
        )
      end

      metadata.compact
    end

    def step_summary(step)
      label = step&.dig("name") || "Step"

      if status_change_activity?(step)
        return status_change_summary
      end

      if sms_step?(step) && @sms_outcome == "sent"
        return "Text sent — #{label}"
      end
      if sms_step?(step) && @sms_outcome == "replied"
        return "Text replied — #{label}"
      end
      if sms_step?(step) && @sms_outcome == "opt_out"
        return "Text opt-out — #{label}"
      end

      "#{label} — #{@outcome.tr('_', ' ')}"
    end

    def status_change_activity?(step)
      sms_step?(step) && @sms_outcome.present? && @sms_outcome.in?(%w[replied no_response opt_out])
    end

    def status_change_summary
      "Status change from #{enrollment_status_label(@status_before)} to #{enrollment_status_label(@status_after)}. #{sms_outcome_label}."
    end

    def sms_outcome_label
      {
        "replied" => "Replied",
        "no_response" => "No response",
        "opt_out" => "Opt-out"
      }.fetch(@sms_outcome, @sms_outcome.humanize)
    end

    def enrollment_status_label(status)
      OutreachEnrollment::STATUS_LABELS.fetch(status.to_s, status.to_s.humanize)
    end

    def sms_step?(step)
      step&.dig("step_type") == Outreach::PlanStepTypes::SEND_SMS
    end

    def apply_customer_sms_compliance!(step)
      return unless sms_step?(step) && @sms_outcome == "opt_out"

      Sms::Compliance.opt_out!(
        customer: @enrollment.customer,
        source: "Outreach log outcome",
        note: @notes
      )
    end
  end
end
