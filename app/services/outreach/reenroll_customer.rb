# frozen_string_literal: true

module Outreach
  class ReenrollCustomer
    Result = Struct.new(:enrollment, :error, keyword_init: true)

    def self.call(enrollment:)
      new(enrollment: enrollment).call
    end

    def initialize(enrollment:)
      @enrollment = enrollment
    end

    def call
      unless @enrollment.reenrollable?
        return Result.new(enrollment: nil, error: "Only Lost or Completed enrollments can be re-enrolled.")
      end

      if OutreachEnrollment.open_for(
        customer: @enrollment.customer,
        campaign: @enrollment.outreach_campaign
      )
        return Result.new(enrollment: nil, error: "An active enrollment already exists for this campaign.")
      end

      result = EnrollCustomer.call(
        customer: @enrollment.customer,
        campaign: @enrollment.outreach_campaign,
        prior_enrollment: @enrollment
      )

      if result.error.present?
        Result.new(enrollment: nil, error: result.error)
      elsif result.created
        Result.new(enrollment: result.enrollment, error: nil)
      else
        Result.new(enrollment: nil, error: "Could not re-enroll.")
      end
    end
  end
end
