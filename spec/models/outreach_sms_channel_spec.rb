# frozen_string_literal: true

require "rails_helper"

RSpec.describe OutreachSmsChannel do
  describe ".find_active_by_from_number" do
    let(:organization) { create(:organization) }

    it "matches stored from_number" do
      OutreachSmsChannel.create!(
        organization: organization,
        active: true,
        from_number: "+13602101996",
        environment: "production"
      )

      channel = described_class.find_active_by_from_number("3602101996")
      expect(channel).to be_present
    end

    it "does not match when from_number is only in ENV" do
      previous = ENV["TWILIO_FROM_NUMBER"]
      ENV["TWILIO_FROM_NUMBER"] = "+13602101996"
      OutreachSmsChannel.create!(
        organization: organization,
        active: true,
        from_number: nil,
        environment: "production"
      )

      expect(described_class.find_active_by_from_number("+13602101996")).to be_nil
    ensure
      ENV["TWILIO_FROM_NUMBER"] = previous
    end

    it "returns nil for inactive channels" do
      OutreachSmsChannel.create!(
        organization: organization,
        active: false,
        from_number: "+13602101996",
        environment: "production"
      )

      expect(described_class.find_active_by_from_number("+13602101996")).to be_nil
    end

    it "requires from_number in Settings for ready_to_send" do
      ENV["TWILIO_ACCOUNT_SID"] = "ACtest"
      ENV["TWILIO_AUTH_TOKEN"] = "secret"

      channel = OutreachSmsChannel.create!(
        organization: organization,
        active: true,
        from_number: nil,
        environment: "production"
      )

      expect(channel.ready_to_send?).to be(false)

      channel.update!(from_number: "+13602101996")
      expect(channel.ready_to_send?).to be(true)
    ensure
      ENV.delete("TWILIO_ACCOUNT_SID")
      ENV.delete("TWILIO_AUTH_TOKEN")
    end
  end
end
