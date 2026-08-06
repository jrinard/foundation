# frozen_string_literal: true

require "rails_helper"

RSpec.describe "LifeSpring contact form opt-in webhook", type: :request do
  let(:organization) { create(:organization, slug: "lifespring", outreach_enabled: true) }
  let(:token) { "test-contact-form-token" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("LIFESPRING_CONTACT_FORM_WEBHOOK_TOKEN").and_return(token)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("LIFESPRING_CONTACT_FORM_ORG_SLUG", "lifespring").and_return("lifespring")
    organization
  end

  let(:payload) do
    {
      name: "Jane Doe",
      business_name: "Doe HVAC",
      email: "jane@doehvac.com",
      phone: "3605559876",
      sms_opt_in: true,
      sms_opt_in_source: "lifespringdesign.com/contact-form",
      sms_opt_in_at: "2026-07-24T20:15:00.000Z",
      sms_opt_in_label: "I agree to receive SMS from LifeSpring Design."
    }
  end

  it "accepts a signed webhook and returns customer id" do
    post lifespring_contact_form_opt_in_path,
         params: payload,
         headers: { "Authorization" => "Bearer #{token}" },
         as: :json

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["ok"]).to be(true)
    expect(body["customer_id"]).to be_present
    expect(body["sms_opt_in"]).to be(true)
    expect(body["sms_opt_in_source"]).to eq("lifespringdesign.com/contact-form")
  end

  it "rejects missing auth" do
    post lifespring_contact_form_opt_in_path, params: payload, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts website review via dedicated route" do
    review_payload = payload.merge(
      sms_opt_in_source: Lifespring::WebsiteSources::WEBSITE_REVIEW,
      sms_opt_in_label: "Yes, text me about my free website review",
      message: "Please review our website."
    )

    post lifespring_website_review_path,
         params: review_payload,
         headers: { "Authorization" => "Bearer #{token}" },
         as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["sms_opt_in_source"]).to eq(Lifespring::WebsiteSources::WEBSITE_REVIEW)
  end

  it "rejects unknown sms_opt_in_source" do
    post lifespring_contact_form_opt_in_path,
         params: payload.merge(sms_opt_in_source: "other-form"),
         headers: { "Authorization" => "Bearer #{token}" },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to include("sms_opt_in_source must be one of")
  end

  it "accepts sms_opt_in_source with https URL prefix" do
    post lifespring_contact_form_opt_in_path,
         params: payload.merge(
           phone: "3605551111",
           email: "url-test@example.com",
           sms_opt_in_source: "https://lifespringdesign.com/contact-form"
         ),
         headers: { "Authorization" => "Bearer #{token}" },
         as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["sms_opt_in_source"]).to eq("lifespringdesign.com/contact-form")
  end
end
