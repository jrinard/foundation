# frozen_string_literal: true

module Outreach
  class EnrollmentsController < BaseController
    before_action :set_enrollment, only: [:show, :complete_step, :send_message, :simulate_reply, :pause, :resume, :reenroll, :dev_reset, :toggle_dev_mode, :return_to_step]
    before_action :require_outreach_dev_tools!, only: [:simulate_reply, :dev_reset, :toggle_dev_mode]
    before_action :require_outreach_dev_mode!, only: [:simulate_reply, :dev_reset]

    def show
      authorize! :read, @enrollment
      @activities = @enrollment.activities.includes(:user).recent_first.limit(30)
      @prior_attempts = OutreachEnrollment
        .where(customer: @enrollment.customer, outreach_campaign: @enrollment.outreach_campaign)
        .where.not(id: @enrollment.id)
        .closed
        .recent_first
      @step_module = Outreach::StepModules.context_for(
        @enrollment,
        sms_recipient_key: sms_recipient_key_for(@enrollment),
        dev_mode: outreach_dev_mode?
      ) unless @enrollment.plan_complete?
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

      result =
        if advance_plan_step_request?
          Outreach::AdvanceStep.call(
            enrollment: @enrollment,
            outcome: "completed",
            notes: params[:notes],
            force_advance: true,
            user: current_user
          )
        elsif sms_step_request?
          Outreach::Sms::CompleteStep.call(
            enrollment: @enrollment,
            sms_outcome: resolved_sms_outcome,
            message_body: params[:message_body],
            notes: params[:notes],
            user: current_user
          )
        else
          Outreach::AdvanceStep.call(
            enrollment: @enrollment,
            outcome: params[:outcome],
            notes: params[:notes],
            user: current_user
          )
        end

      if result.error.present?
        redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: result.error
      else
        notice = advance_plan_step_request? ? "Plan step complete — moved to the next step." : "Step updated."
        redirect_to outreach_enrollment_path(@enrollment), notice: notice
      end
    end

    def send_message
      authorize! :update, @enrollment

      recipient = Outreach::Sms::RecipientOptions.find(customer: @enrollment.customer, key: params[:sms_recipient_key])
      unless recipient&.phone_normalized.present? || outreach_dev_mode?
        redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: "Add a phone number before sending."
        return
      end

      result = Outreach::Sms::SendMessage.call(
        enrollment: @enrollment,
        body: params[:message_body],
        recipient_key: params[:sms_recipient_key],
        user: current_user
      )

      if result.error.present?
        redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: result.error
      else
        persist_sms_recipient_key!(@enrollment, params[:sms_recipient_key])
        redirect_to outreach_enrollment_path(@enrollment), notice: "Message sent."
      end
    end

    def simulate_reply
      authorize! :update, @enrollment

      result = Outreach::Sms::SimulateInboundReply.call(
        enrollment: @enrollment,
        reply_type: params[:reply_type],
        recipient_key: params[:sms_recipient_key].presence || sms_recipient_key_for(@enrollment),
        user: current_user
      )

      if result.error.present?
        redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: result.error
      else
        persist_sms_recipient_key!(@enrollment, params[:sms_recipient_key])
        redirect_to outreach_enrollment_path(@enrollment), notice: "Simulated reply added."
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

    def dev_reset
      authorize! :update, @enrollment
      result = Outreach::Sms::ResetEnrollmentConversation.call(enrollment: @enrollment)

      if result.error.present?
        redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: result.error
      else
        redirect_to outreach_enrollment_path(@enrollment), notice: "Dev reset — all messages deleted, back to step 1."
      end
    end

    def toggle_dev_mode
      authorize! :update, @enrollment

      session[:outreach_dev_mode] = !outreach_dev_mode?
      notice = outreach_dev_mode? ? "Dev Mode on — shortcuts enabled." : "Dev Mode off."
      redirect_to outreach_enrollment_path(@enrollment), notice: notice
    end

    def return_to_step
      authorize! :update, @enrollment

      result = Outreach::ReturnToStep.call(
        enrollment: @enrollment,
        step_position: params[:step_position],
        user: current_user
      )

      if result.error.present?
        redirect_to outreach_enrollment_path(@enrollment), alert: result.error
      else
        redirect_to outreach_enrollment_path(result.enrollment), notice: "Returned to step #{params[:step_position]}."
      end
    end

    private

    def set_enrollment
      @enrollment = OutreachEnrollment.find(params[:id])
    end

    def advance_plan_step_request?
      return false unless @enrollment.current_step_type == Outreach::PlanStepTypes::SEND_SMS

      params[:advance_plan_step].present?
    end

    def sms_step_request?
      return false if advance_plan_step_request?
      return false unless @enrollment.current_step_type == Outreach::PlanStepTypes::SEND_SMS

      params[:sms_outcome].present?
    end

    def resolved_sms_outcome
      Array(params[:sms_outcome]).last.to_s
    end

    def sms_recipient_key_for(enrollment)
      session.dig(:outreach_sms_recipient_keys, enrollment.id.to_s).presence ||
        Outreach::Sms::RecipientOptions.default_key(customer: enrollment.customer)
    end

    def persist_sms_recipient_key!(enrollment, key)
      return if key.blank?

      session[:outreach_sms_recipient_keys] ||= {}
      session[:outreach_sms_recipient_keys][enrollment.id.to_s] = key.to_s
    end

    def require_outreach_dev_mode!
      return if outreach_dev_mode?

      redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: "Turn on Dev Mode to use this."
    end

    def require_outreach_dev_tools!
      return if outreach_dev_tools_available?

      redirect_back fallback_location: outreach_enrollment_path(@enrollment), alert: "Not authorized."
    end
  end
end
