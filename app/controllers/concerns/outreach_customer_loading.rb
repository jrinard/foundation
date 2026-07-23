# frozen_string_literal: true

module OutreachCustomerLoading
  extend ActiveSupport::Concern

  private

  def load_outreach_for_customer!(customer)
    return unless outreach_enabled? && customer.present?

    @outreach_enrollments = customer.outreach_enrollments.includes(:outreach_campaign, :outreach_plan).recent_first
    @outreach_campaigns = OutreachCampaign.active.includes(:outreach_plan).recent_first
    @promote_lists = List.order(:row_order).pluck(:name, :id)
    @default_promote_list_id = List.default_for_new_leads_id
  end
end
