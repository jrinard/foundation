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
  end
end
