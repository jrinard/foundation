# frozen_string_literal: true

module Outreach
  module Sms
    class ResetEnrollmentConversation
      Result = Struct.new(:enrollment, :error, keyword_init: true) do
        def success?
          error.blank?
        end
      end

      def self.call(enrollment:)
        new(enrollment: enrollment).call
      end

      def initialize(enrollment:)
        @enrollment = enrollment
      end

      def call
        ActiveRecord::Base.transaction do
          @enrollment.text_messages.destroy_all
          @enrollment.activities.destroy_all
          @enrollment.update!(
            current_step_position: 1,
            status: OutreachEnrollment::STATUS_READY,
            paused_at: nil
          )
        end

        Result.new(enrollment: @enrollment.reload, error: nil)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(enrollment: @enrollment, error: e.record.errors.full_messages.to_sentence)
      end
    end
  end
end
