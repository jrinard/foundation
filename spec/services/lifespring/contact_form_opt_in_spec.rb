# frozen_string_literal: true

require "rails_helper"

RSpec.describe Lifespring::ContactFormOptIn do
  let(:organization) { create(:organization, slug: "lifespring-test", outreach_enabled: true, potentials_enabled: true) }

  let(:payload) do
    {
      name: "John Smith",
      business_name: "Acme Plumbing",
      email: "john@acme.com",
      phone: "3605551234",
      message: "Need help with our website",
      sms_opt_in: true,
      sms_opt_in_source: "lifespringdesign.com/contact-form",
      sms_opt_in_at: "2026-07-24T20:15:00.000Z",
      sms_opt_in_label: "By checking this box, you agree to receive text messages from LifeSpring Design."
    }
  end

  describe ".call" do
    it "creates a potential customer with SMS opt-in audit fields" do
      result = described_class.call(payload: payload, organization: organization)

      expect(result).to be_success
      expect(result.created).to be(true)

      customer = result.customer
      expect(customer.name).to eq("Acme Plumbing")
      expect(customer.phone).to eq("3605551234")
      expect(customer.email).to eq("john@acme.com")
      expect(customer.onBoard).to eq("The List")
      expect(customer.sms_opted_in?).to be(true)
      expect(customer.sms_opt_in_source).to eq("lifespringdesign.com/contact-form")
      expect(customer.sms_opt_in_at).to eq(Time.zone.parse("2026-07-24T20:15:00.000Z"))
      expect(customer.sms_opt_in_label).to include("text messages")

      contact = customer.contacts.find_by(position: "WebForm")
      expect(contact).to be_present
      expect(contact.firstname).to eq("John")
      expect(contact.lastname).to eq("Smith")
      expect(contact.phone).to eq("3605551234")
      expect(contact.email).to eq("john@acme.com")

      note = customer.notes.find_by(name: "Website opt-in")
      expect(note).to be_present
      expect(note.text).to include("LifeSpring contact form")
      expect(note.text).to include("July 24, 2026")
      expect(note.text).to include("lifespringdesign.com/contact-form")
      expect(note.text).to include("text messages")
      expect(note.account_note).to be(false)
    end

    it "updates an existing customer matched by phone and moves them to Prospects" do
      existing = create(
        :customer,
        organization: organization,
        name: "Old Name",
        phone: "360-555-1234",
        onBoard: "Lead on Board",
        list_id: create(:list, organization: organization).id,
        sms_opt_in: nil
      )

      result = described_class.call(payload: payload, organization: organization)

      expect(result.created).to be(false)
      expect(result.customer.id).to eq(existing.id)
      expect(result.customer.onBoard).to eq(Lifespring::ContactFormOptIn::PROSPECTS_ON_BOARD)
      expect(result.customer.list_id).to be_nil
      expect(result.customer.sms_opted_in?).to be(true)
      expect(result.customer.name).to eq("Acme Plumbing")

      contact = result.customer.contacts.find_by(position: "WebForm")
      expect(contact.firstname).to eq("John")
      expect(contact.email).to eq("john@acme.com")

      expect(result.customer.notes.where(name: "Website opt-in").count).to eq(1)
    end

    it "updates the WebForm contact and adds a new activity note on repeat submissions" do
      existing = create(
        :customer,
        organization: organization,
        name: "Acme Plumbing",
        phone: "3605551234",
        onBoard: "The List"
      )
      existing.contacts.create!(
        organization: organization,
        position: "WebForm",
        firstname: "Old",
        lastname: "Name",
        email: "old@acme.com"
      )

      result = described_class.call(payload: payload, organization: organization)

      contact = result.customer.contacts.find_by(position: "WebForm")
      expect(contact.firstname).to eq("John")
      expect(contact.lastname).to eq("Smith")
      expect(result.customer.notes.where(name: "Website opt-in").count).to eq(1)

      described_class.call(payload: payload.merge(name: "John Smith Jr."), organization: organization)

      expect(contact.reload.lastname).to eq("Smith Jr.")
      expect(result.customer.notes.where(name: "Website opt-in").count).to eq(2)
    end

    it "creates a website review prospect with review notes" do
      review_payload = payload.merge(
        sms_opt_in_source: Lifespring::WebsiteSources::WEBSITE_REVIEW,
        message: "Please review our homepage."
      )

      result = described_class.call(payload: review_payload, organization: organization)

      expect(result).to be_success
      expect(result.customer.sms_opt_in_source).to eq(Lifespring::WebsiteSources::WEBSITE_REVIEW)
      expect(result.customer.extra_notes).to start_with("LifeSpring website review")
    end

    it "rejects unknown sms_opt_in_source" do
      result = described_class.call(
        payload: payload.merge(sms_opt_in_source: "unknown-source"),
        organization: organization
      )

      expect(result).not_to be_success
      expect(result.error).to include("sms_opt_in_source must be one of")
    end
  end
end
