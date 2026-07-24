# frozen_string_literal: true

module Lifespring
  class NotifyAdminWebsiteOptIn
    ADMIN_PHONE = ENV.fetch("LIFESPRING_OPT_IN_ADMIN_PHONE", "2083168338")

    def self.call(customer:, organization:, payload: {})
      new(customer: customer, organization: organization, payload: payload).call
    end

    def initialize(customer:, organization:, payload: {})
      @customer = customer
      @organization = organization
      @payload = payload.to_h.with_indifferent_access
    end

    def call
      channel = OutreachSmsChannel.integration_for(@organization)
      return log_skip("admin alerts disabled") unless channel.notify_admin_on_website_opt_in?

      unless channel.ready_to_send?
        return log_skip("Twilio channel not ready to send")
      end

      to = Outreach::Sms::PhoneNumber.normalize(ADMIN_PHONE)
      return log_skip("admin phone invalid") if to.blank?

      body = build_body
      result = Outreach::Sms::TwilioClient.new(channel).send_message(to: to, body: body)

      if result.success?
        Rails.logger.info("=== Admin website opt-in alert sent to #{to}")
      else
        Rails.logger.error("Admin website opt-in alert failed: #{result.error}")
      end

      result
    end

    private

    def build_body
      [
        notification_heading,
        display_name,
        display_email,
        display_phone
      ].compact.join(" - ")
    end

    def notification_heading
      source = @customer.sms_opt_in_source.to_s
      if source.include?(WebsiteSources::WEBSITE_REVIEW_SOURCE_FRAGMENT)
        "New Website Review Opt-in"
      else
        "New Contact Form Opt-in"
      end
    end

    def display_name
      @customer.name.presence || @payload[:business_name].presence || @payload[:name].presence
    end

    def display_email
      @payload[:email].presence || @customer.email.presence
    end

    def display_phone
      @payload[:phone].presence || @customer.phone.presence
    end

    def log_skip(reason)
      Rails.logger.info("Admin website opt-in alert skipped: #{reason}")
      nil
    end
  end
end
