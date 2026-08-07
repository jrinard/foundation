# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Outreach enrollment poll", type: :request do
  let(:organization) { create(:organization, outreach_enabled: true) }
  let(:user) { create(:user, role: "admin") }
  let(:customer) { create(:customer, organization: organization) }
  let(:plan) { OutreachPlan.create!(organization: organization, name: "Poll Test Plan", active: true) }
  let(:campaign) do
    OutreachCampaign.create!(
      organization: organization,
      outreach_plan: plan,
      name: "Poll Test Campaign",
      status: OutreachCampaign::STATUS_ACTIVE
    )
  end
  let(:enrollment) do
    OutreachEnrollment.create!(
      organization: organization,
      customer: customer,
      outreach_campaign: campaign,
      outreach_plan: plan,
      current_step_position: 1,
      status: OutreachEnrollment::STATUS_CONTACTED,
      plan_snapshot: [{ "position" => 1, "name" => "SMS", "step_type" => "send_sms" }],
      enrolled_at: Time.current
    )
  end

  before do
    create(:organization_membership, user: user, organization: organization, role: "admin")
    sign_in user
  end

  it "returns inbound message stats for the enrollment thread" do
    OutreachTextMessage.create!(
      organization: organization,
      outreach_enrollment: enrollment,
      customer: customer,
      direction: OutreachTextMessage::DIRECTION_OUTBOUND,
      body: "Hello",
      status: OutreachTextMessage::STATUS_SENT
    )
    inbound = OutreachTextMessage.create!(
      organization: organization,
      outreach_enrollment: enrollment,
      customer: customer,
      direction: OutreachTextMessage::DIRECTION_INBOUND,
      body: "Yes",
      status: OutreachTextMessage::STATUS_RECORDED
    )

    get poll_outreach_enrollment_path(enrollment), as: :json

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["inbound_count"]).to eq(1)
    expect(body["last_inbound_id"]).to eq(inbound.id)
    expect(body["conversation_html"]).to include("Yes")
    expect(body["activity_html"]).to be_present
  end

  it "ignores outbound-only changes" do
    OutreachTextMessage.create!(
      organization: organization,
      outreach_enrollment: enrollment,
      customer: customer,
      direction: OutreachTextMessage::DIRECTION_OUTBOUND,
      body: "Hello",
      status: OutreachTextMessage::STATUS_SENT
    )

    get poll_outreach_enrollment_path(enrollment), as: :json

    expect(response.parsed_body["inbound_count"]).to eq(0)
    expect(response.parsed_body["last_inbound_id"]).to be_nil
  end
end
