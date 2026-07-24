# frozen_string_literal: true

module Outreach
  class ReturnToStep
    Result = Struct.new(:enrollment, :error, keyword_init: true) do
      def success?
        error.blank?
      end
    end

    def self.call(enrollment:, step_position:, user: Current.user)
      new(enrollment: enrollment, step_position: step_position, user: user).call
    end

    def initialize(enrollment:, step_position:, user:)
      @enrollment = enrollment
      @step_position = step_position.to_i
      @user = user
    end

    def call
      return Result.new(enrollment: @enrollment, error: "Enrollment is paused.") if @enrollment.paused?
      return Result.new(enrollment: @enrollment, error: "Enrollment is closed.") if @enrollment.closed?
      return Result.new(enrollment: @enrollment, error: "Pick a valid step.") unless target_step
      return Result.new(enrollment: @enrollment, error: "You are already on that step.") if @step_position == @enrollment.current_step_position
      return Result.new(enrollment: @enrollment, error: "That step is not complete yet.") unless @step_position < @enrollment.current_step_position

      @from_step_position = @enrollment.current_step_position

      ActiveRecord::Base.transaction do
        apply_return!
        log_activity!
      end

      Result.new(enrollment: @enrollment.reload, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(enrollment: @enrollment, error: e.record.errors.full_messages.to_sentence)
    end

    private

    def target_step
      @target_step ||= @enrollment.plan_steps.find { |step| step["position"].to_i == @step_position }
    end

    def apply_return!
      attrs = { current_step_position: @step_position }

      if @enrollment.status == OutreachEnrollment::STATUS_COMPLETED
        attrs[:status] = OutreachEnrollment::STATUS_CONTACTED
      end

      @enrollment.update!(attrs)
    end

    def log_activity!
      OutreachActivity.create!(
        organization: @enrollment.organization,
        outreach_enrollment: @enrollment,
        user: @user,
        activity_type: "step_returned",
        summary: "Returned to step #{@step_position} — #{target_step['name']}",
        metadata: {
          step_position: @step_position,
          step_name: target_step["name"],
          step_type: target_step["step_type"],
          from_step_position: @from_step_position
        }.compact
      )
    end
  end
end
