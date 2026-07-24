# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customer, type: :model do
  let(:organization) { create(:organization) }

  def potential(attrs = {})
    create(
      :customer,
      organization: organization,
      onBoard: "The List",
      active: false,
      archived: false,
      **attrs
    )
  end

  describe ".ordered_for_prospects_list" do
    it "orders by sms_opt_in_at then created_at, newest first" do
      older = potential(name: "Older", created_at: 2.days.ago, sms_opt_in_at: 1.day.ago)
      newer = potential(name: "Newer", created_at: 1.hour.ago, sms_opt_in_at: 1.hour.ago)
      no_opt_in = potential(name: "No opt-in", created_at: 30.minutes.ago, sms_opt_in_at: nil)

      ids = described_class.potential_customers.ordered_for_prospects_list.pluck(:id)

      expect(ids).to eq([newer.id, older.id, no_opt_in.id])
    end
  end

  describe ".apply_prospects_source_filter" do
    it "returns website contact form prospects" do
      match = potential(sms_opt_in_source: "lifespringdesign.com/contact-form", sms_opt_in_at: Time.current)
      other = potential(sms_opt_in_source: "manual")

      ids = described_class.potential_customers
        .merge(described_class.apply_prospects_source_filter("website_contact_form"))
        .pluck(:id)

      expect(ids).to eq([match.id])
    end

    it "returns prospects opted in today" do
      today = potential(sms_opt_in_at: Time.zone.today.noon)
      yesterday = potential(sms_opt_in_at: 1.day.ago)

      ids = described_class.potential_customers
        .merge(described_class.apply_prospects_source_filter("opted_in_today"))
        .pluck(:id)

      expect(ids).to eq([today.id])
    end
  end

  describe "#website_contact_form_opt_in?" do
    it "is true when source contains contact-form" do
      customer = potential(sms_opt_in_source: "lifespringdesign.com/contact-form")
      expect(customer.website_contact_form_opt_in?).to be(true)
    end
  end
end
