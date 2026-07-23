# frozen_string_literal: true

module Outreach
  class CampaignEnrollmentsController < BaseController
    before_action :set_campaign

    def create
      authorize! :create, OutreachEnrollment
      unless @campaign.open_for_enrollment?
        redirect_to outreach_campaign_path(@campaign), alert: "This campaign is closed."
        return
      end

      customer = Customer.potential_customers.find(params[:customer_id])
      result = Outreach::EnrollCustomer.call(customer: customer, campaign: @campaign)

      if result.error.present?
        redirect_to outreach_campaign_path(@campaign), alert: result.error
      elsif result.created
        notice = result.reenrolled ? "#{customer.name} re-enrolled." : "#{customer.name} enrolled."
        redirect_to outreach_campaign_path(@campaign), notice: notice
      else
        redirect_to outreach_campaign_path(@campaign), alert: "#{customer.name} is already in this campaign."
      end
    end

    private

    def set_campaign
      @campaign = OutreachCampaign.find(params[:campaign_id])
    end
  end
end
