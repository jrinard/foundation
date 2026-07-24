# frozen_string_literal: true

module Outreach
  module Sms
    class CompleteStep
      OUTCOME_MAP = {
        "sent" => "waiting",
        "replied" => "conversation",
        "no_response" => "waiting",
        "opt_out" => "not_interested"
      }.freeze

      def self.call(enrollment:, sms_outcome:, message_body: nil, notes: nil, user: Current.user)
        new(
          enrollment: enrollment,
          sms_outcome: sms_outcome,
          message_body: message_body,
          notes: notes,
          user: user
        ).call
      end

      def initialize(enrollment:, sms_outcome:, message_body:, notes:, user:)
        @enrollment = enrollment
        @sms_outcome = sms_outcome.to_s
        @message_body = message_body.to_s.strip.presence
        @notes = notes
        @user = user
      end

      def call
        unless OUTCOME_MAP.key?(@sms_outcome)
          return AdvanceStep::Result.new(enrollment: @enrollment, error: "Pick a valid SMS outcome.")
        end

        outcome = OUTCOME_MAP[@sms_outcome]

        result = AdvanceStep.call(
          enrollment: @enrollment,
          outcome: outcome,
          notes: @notes,
          message_body: @message_body,
          sms_outcome: @sms_outcome,
          user: @user
        )

        result
      end
    end
  end
end
