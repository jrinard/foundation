# frozen_string_literal: true

module Outreach
  class AdvanceStep
    Result = Struct.new(:enrollment, :error, keyword_init: true)

    def self.call(enrollment:, outcome:, notes: nil, user: Current.user)
      new(enrollment: enrollment, outcome: outcome, notes: notes, user: user).call
    end

    def initialize(enrollment:, outcome:, notes:, user:)
      @enrollment = enrollment
      @outcome = outcome.to_s
      @notes = notes
      @user = user
    end

    def call
      return Result.new(enrollment: @enrollment, error: "Enrollment is paused.") if @enrollment.paused?

      ActiveRecord::Base.transaction do
        step_being_completed = @enrollment.current_step
        apply_status!
        log_activity!(step_being_completed)
        advance_position! unless @outcome.in?(%w[follow_up_later not_interested])
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

    def advance_position!
      return if @outcome.in?(%w[follow_up_later not_interested])

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
        activity_type: "step_completed",
        summary: step_summary(step),
        metadata: {
          outcome: @outcome,
          notes: @notes,
          step_position: step&.dig("position"),
          step_name: step&.dig("name"),
          step_type: step&.dig("step_type")
        }.compact
      )
    end

    def step_summary(step)
      label = step&.dig("name") || "Step"
      "#{label} — #{@outcome.tr('_', ' ')}"
    end
  end
end
