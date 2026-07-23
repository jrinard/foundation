# frozen_string_literal: true

module Outreach
  class CustomerPromotionsController < BaseController
    def create
      customer = Customer.find(params[:customer_id])
      authorize! :update, customer

      result = Outreach::PromoteToLeadPipeline.call(
        customer: customer,
        list_id: params[:list_id],
        user: current_user
      )

      if result.success?
        redirect_to customers_path(id: customer.id), notice: "#{customer.name} moved to Leads (#{result.list.name})."
      else
        redirect_back fallback_location: outreach_customer_return_path(customer), alert: result.error
      end
    end
  end
end
