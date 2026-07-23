# frozen_string_literal: true

module Outreach
  class CampaignsController < BaseController
    before_action :set_campaign, only: [:show, :edit, :update, :close, :destroy]

    def index
      scope = OutreachCampaign.includes(:outreach_plan, :enrollments).recent_first
      @show_completed = show_completed_campaigns?
      scope = scope.excluding_completed unless @show_completed
      @campaigns = scope
    end

    def show
      authorize! :read, @campaign
      @enrollments = OutreachEnrollment.current_enrollments_for(@campaign)
      enrolled_ids = @campaign.enrollments.open.select(:customer_id)
      @enrollable_potentials = Customer.potential_customers
        .where.not(id: enrolled_ids)
        .order(created_at: :desc)
    end

    def new
      authorize! :create, OutreachCampaign
      @default_plan = OutreachPlan.default_for_organization
      @campaign = OutreachCampaign.new(
        status: OutreachCampaign::STATUS_ACTIVE,
        outreach_plan: @default_plan
      )
    end

    def create
      authorize! :create, OutreachCampaign
      @campaign = OutreachCampaign.new(campaign_params)
      @campaign.organization = current_organization
      @campaign.outreach_plan ||= OutreachPlan.default_for_organization

      if @campaign.save
        redirect_to outreach_campaign_path(@campaign), notice: "Campaign created."
      else
        @default_plan = OutreachPlan.default_for_organization
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize! :update, @campaign
      @default_plan = @campaign.outreach_plan || OutreachPlan.default_for_organization
    end

    def update
      authorize! :update, @campaign
      if @campaign.update(campaign_params)
        if params[:return_to] == "index"
          redirect_to outreach_campaigns_path, notice: "Campaign updated."
        else
          redirect_to outreach_campaign_path(@campaign), notice: "Campaign updated."
        end
      elsif params[:return_to] == "index"
        redirect_to outreach_campaigns_path, alert: @campaign.errors.full_messages.to_sentence
      else
        @default_plan = @campaign.outreach_plan || OutreachPlan.default_for_organization
        render :edit, status: :unprocessable_entity
      end
    end

    def close
      authorize! :update, @campaign
      if @campaign.completed?
        redirect_to outreach_campaign_path(@campaign), alert: "Campaign is already closed."
        return
      end

      @campaign.update!(status: OutreachCampaign::STATUS_COMPLETED)
      redirect_to outreach_campaigns_path, notice: "#{@campaign.name} closed."
    end

    def destroy
      authorize! :destroy, @campaign
      if @campaign.enrollments.any?
        redirect_to outreach_campaign_path(@campaign),
          alert: "Cannot delete a campaign with enrollments. Close it instead."
        return
      end

      name = @campaign.name
      @campaign.destroy!
      redirect_to outreach_campaigns_path, notice: "#{name} deleted."
    end

    private

    def set_campaign
      @campaign = OutreachCampaign.find(params[:id])
    end

    def campaign_params
      params.require(:outreach_campaign).permit(
        :name,
        :description,
        :outreach_plan_id,
        :status,
        :cohort_goal
      )
    end

    def show_completed_campaigns?
      params[:show_completed] == "1"
    end
  end
end
