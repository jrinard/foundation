# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lifespring::NotifyAdminWebsiteOptIn do
  let(:organization) { create(:organization, outreach_enabled: true) }
  let(:channel) do
    OutreachSmsChannel.create!(
      organization: organization,
      active: true,
      from_number: "+13602101996",
      environment: "sandbox",
      notify_admin_on_website_opt_in: true
    )
  end
  let(:customer) do
    create(
      :customer,
      organization: organization,
      name: "Sunrise Bakery",
      email: "hello@sunrise.com",
      phone: "3605550199",
      sms_opt_in_source: Lifespring::WebsiteSources::CONTACT_FORM
    )
  end
  let(:payload) do
    {
      name: "Jordan",
      business_name: "Sunrise Bakery",
      email: "hello@sunrise.com",
      phone: "3605550199"
    }
  end

  before do
    channel
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TWILIO_ACCOUNT_SID").and_return("ACtest")
    allow(ENV).to receive(:[]).with("TWILIO_AUTH_TOKEN").and_return("test-token")
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("LIFESPRING_OPT_IN_ADMIN_PHONE", "2083168338").and_return("2083168338")
  end

  it "texts the admin with contact form details" do
    twilio = instance_double(Outreach::Sms::TwilioClient)
    allow(Outreach::Sms::TwilioClient).to receive(:new).with(channel).and_return(twilio)
    allow(twilio).to receive(:send_message).and_return(
      Outreach::Sms::TwilioClient::Result.new(success: true, sid: "SM123", error: nil)
    )

    described_class.call(customer: customer, organization: organization, payload: payload)

    expect(twilio).to have_received(:send_message).with(
      to: "+12083168338",
      body: "New Contact Form Opt-in - Sunrise Bakery - hello@sunrise.com - 3605550199"
    )
  end

  it "uses website review heading for review source" do
    customer.update!(sms_opt_in_source: Lifespring::WebsiteSources::WEBSITE_REVIEW)
    twilio = instance_double(Outreach::Sms::TwilioClient)
    allow(Outreach::Sms::TwilioClient).to receive(:new).and_return(twilio)
    allow(twilio).to receive(:send_message).and_return(
      Outreach::Sms::TwilioClient::Result.new(success: true, sid: "SM123", error: nil)
    )

    described_class.call(customer: customer, organization: organization, payload: payload)

    expect(twilio).to have_received(:send_message).with(
      hash_including(body: a_string_starting_with("New Website Review Opt-in"))
    )
  end

  it "skips when admin alerts are disabled" do
    channel.update!(notify_admin_on_website_opt_in: false)
    twilio = instance_double(Outreach::Sms::TwilioClient)
    allow(Outreach::Sms::TwilioClient).to receive(:new).and_return(twilio)
    allow(twilio).to receive(:send_message)

    described_class.call(customer: customer, organization: organization, payload: payload)

    expect(twilio).not_to have_received(:send_message)
  end
end
