# frozen_string_literal: true

module Outreach
  class EnrollCustomer
    Result = Struct.new(:enrollment, :created, :reenrolled, :error, keyword_init: true)

    def self.call(customer:, campaign:, prior_enrollment: nil)
      new(customer: customer, campaign: campaign, prior_enrollment: prior_enrollment).call
    end

    def initialize(customer:, campaign:, prior_enrollment: nil)
      @customer = customer
      @campaign = campaign
      @plan = campaign.outreach_plan
      @prior_enrollment = prior_enrollment
    end

    def call
      open = OutreachEnrollment.open_for(customer: @customer, campaign: @campaign)
      return Result.new(enrollment: open, created: false, reenrolled: false, error: nil) if open

      enrollment = nil
      reenrolled = @prior_enrollment.present? || prior_closed_attempt?

      ActiveRecord::Base.transaction do
        enrollment = OutreachEnrollment.create!(
          organization: @customer.organization,
          customer: @customer,
          outreach_campaign: @campaign,
          outreach_plan: @plan,
          current_step_position: 1,
          status: OutreachEnrollment::STATUS_READY,
          plan_snapshot: @plan.snapshot_steps,
          enrolled_at: Time.current
        )

        OutreachActivity.create!(
          organization: enrollment.organization,
          outreach_enrollment: enrollment,
          user: Current.user,
          activity_type: "enrolled",
          summary: enrollment_summary(reenrolled),
          metadata: enrollment_metadata(enrollment, reenrolled)
        )
      end

      Result.new(enrollment: enrollment, created: true, reenrolled: reenrolled, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(enrollment: nil, created: false, reenrolled: false, error: e.record.errors.full_messages.to_sentence)
    end

    private

    def prior_closed_attempt?
      OutreachEnrollment.closed.exists?(
        customer: @customer,
        outreach_campaign: @campaign
      )
    end

    def enrollment_summary(reenrolled)
      if reenrolled
        "Re-enrolled in #{@campaign.name}"
      else
        "Added to campaign #{@campaign.name}"
      end
    end

    def enrollment_metadata(enrollment, reenrolled)
      metadata = {
        campaign_id: @campaign.id,
        plan_id: @plan.id
      }
      metadata[:prior_enrollment_id] = @prior_enrollment.id if @prior_enrollment
      metadata[:reenrolled] = true if reenrolled
      metadata
    end
  end
end
