# frozen_string_literal: true

module Outreach
  # Maps plan step_type → enrollment show UI module (not step position).
  # Add new channels here when phone/email modules ship.
  module StepModules
    PARTIALS = {
      PlanStepTypes::SEND_SMS => "outreach/enrollments/step_modules/sms"
    }.freeze

    def self.partial_for(step_type)
      PARTIALS[step_type.to_s]
    end

    def self.registered?(step_type)
      partial_for(step_type).present?
    end

    def self.context_for(enrollment, sms_recipient_key: nil, dev_mode: false, dev_tools_available: false)
      step_type = enrollment.current_step_type
      return nil unless registered?(step_type)

      case step_type
      when PlanStepTypes::SEND_SMS
        Sms::StepContext.new(
          enrollment: enrollment,
          sms_recipient_key: sms_recipient_key,
          dev_mode: dev_mode,
          dev_tools_available: dev_tools_available
        )
      end
    end
  end
end
