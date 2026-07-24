# frozen_string_literal: true

module Outreach
  class BaseController < ApplicationController
    include NavModuleRequired
    include OutreachCustomerLoading

    require_nav_module :outreach

    before_action :authorize_outreach!

    layout "application"

    private

    def authorize_outreach!
      authorize! :read, OutreachCampaign
    end

    def outreach_dev_tools_available?
      current_user&.superadmin? && !Rails.env.production?
    end

    def outreach_dev_mode?
      session[:outreach_dev_mode] == true
    end
    helper_method :outreach_dev_mode?, :outreach_dev_tools_available?
  end
end
