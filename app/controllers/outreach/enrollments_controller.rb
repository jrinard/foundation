# frozen_string_literal: true

module Outreach
  class EnrollmentsController < BaseController
    before_action :set_enrollment, only: [:show, :complete_step, :pause, :resume, :reenroll]

    def show
      authorize! :read, @enrollment
      @activities = @enrollment.activities.includes(:user).recent_first.limit(30)
      @prior_attempts = OutreachEnrollment
        .where(customer: @enrollment.customer, outreach_campaign: @enrollment.outreach_campaign)
        .where.not(id: @enrollment.id)
        .closed
        .recent_first
      load_outreach_for_customer!(@enrollment.customer) if outreach_enabled?
    end

    def create
      authorize! :create, OutreachEnrollment
      customer = Customer.potential_customers.find(params[:customer_id])
      campaign = OutreachCampaign.find(params[:outreach_campaign_id])

      result = Outreach::EnrollCustomer.call(customer: customer, campaign: campaign)

      if result.error.present?
        redirect_back fallback_location: outreach_customer_return_path(customer), alert: result.error
      elsif result.created
        notice = result.reenrolled ? "Re-enrolled in #{campaign.name}." : "Added to #{campaign.name}."
        redirect_back fallback_location: outreach_enrollment_path(result.enrollment), notice: notice
      else
        redirect_back fallback_location: outreach_customer_return_path(customer), alert: "Already in this campaign."
      end
    end

    def reenroll
      authorize! :create, OutreachEnrollment
      result = Outreach::ReenrollCustomer.call(enrollment: @enrollment)

      if result.error.present?
        redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: result.error
      else
        redirect_to outreach_enrollment_path(result.enrollment), notice: "Re-enrolled in #{@enrollment.outreach_campaign.name}."
      end
    end

    def complete_step
      authorize! :update, @enrollment
      result = Outreach::AdvanceStep.call(
        enrollment: @enrollment,
        outcome: params[:outcome],
        notes: params[:notes],
        user: current_user
      )

      if result.error.present?
        redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: result.error
      else
        redirect_to outreach_enrollment_path(@enrollment), notice: "Step updated."
      end
    end

    def pause
      authorize! :update, @enrollment
      @enrollment.update!(status: OutreachEnrollment::STATUS_PAUSED, paused_at: Time.current)
      redirect_back fallback_location: outreach_enrollment_path(@enrollment), notice: "Enrollment paused."
    end

    def resume
      authorize! :update, @enrollment
      @enrollment.update!(status: OutreachEnrollment::STATUS_CONTACTED, paused_at: nil)
      redirect_back fallback_location: outreach_enrollment_path(@enrollment), notice: "Enrollment resumed."
    end

    private

    def set_enrollment
      @enrollment = OutreachEnrollment.find(params[:id])
    end
  end
end
