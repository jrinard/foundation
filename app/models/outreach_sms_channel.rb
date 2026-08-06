# frozen_string_literal: true

class OutreachSmsChannel < ApplicationRecord
  include OrganizationScoped

  ENVIRONMENT = "production"

  DEFAULT_OPT_OUT_REPLY = "You have been unsubscribed. Reply YES to opt back in."
  DEFAULT_OPT_IN_REPLY = "Thank you for opting in. Reply STOP to unsubscribe or HELP for assistance."
  DEFAULT_HELP_REPLY = "LifeSpring Design: For help email josh@lifespringdesign.com or call (208) 316-8338. Reply STOP to unsubscribe."

  belongs_to :organization

  before_validation :assign_production_environment

  validates :environment, presence: true, inclusion: { in: [ENVIRONMENT] }
  validates :organization_id, uniqueness: true

  def self.integration_for(organization)
    return nil unless organization

    find_or_create_by!(organization: organization) do |record|
      record.environment = ENVIRONMENT
      record.active = false
      record.notify_admin_on_website_opt_in = true
    end
  end

  def self.find_active_by_from_number(raw_number)
    normalized = Outreach::Sms::PhoneNumber.normalize(raw_number)
    return nil if normalized.blank?

    unscoped_by_organization
      .where(active: true)
      .find { |channel| Outreach::Sms::PhoneNumber.normalize(channel.from_number) == normalized }
  end

  def credentials_present?
    effective_account_sid.present? && effective_auth_token.present? && org_from_number_configured?
  end

  def org_from_number_configured?
    from_number.present?
  end

  def configured?
    active? && credentials_present?
  end

  def ready_to_send?
    configured?
  end

  def effective_account_sid
    account_sid.presence || ENV["TWILIO_ACCOUNT_SID"].presence
  end

  def effective_auth_token
    auth_token.presence || ENV["TWILIO_AUTH_TOKEN"].presence
  end

  def effective_from_number
    from_number.presence
  end

  def env_account_sid_present?
    ENV["TWILIO_ACCOUNT_SID"].present?
  end

  def env_auth_token_present?
    ENV["TWILIO_AUTH_TOKEN"].present?
  end

  def credentials_source_label
    if env_account_sid_present? && env_auth_token_present?
      "Platform ENV"
    else
      "Set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN in ENV"
    end
  end

  def status_label
    return "Active — ready to send" if configured?
    return "Inactive — credentials present but channel not active" if credentials_present? && !active?
    return "Set from number in Settings → Outreach → Text Messages" if active? && !org_from_number_configured?

    "Not configured"
  end

  def effective_opt_out_reply
    opt_out_reply_message.presence || DEFAULT_OPT_OUT_REPLY
  end

  def effective_opt_in_reply
    opt_in_reply_message.presence || DEFAULT_OPT_IN_REPLY
  end

  def opt_out_twiml
    twiml_for(effective_opt_out_reply)
  end

  def opt_in_twiml
    twiml_for(effective_opt_in_reply)
  end

  def help_twiml
    twiml_for(effective_help_reply)
  end

  def effective_help_reply
    ENV["LIFESPRING_SMS_HELP_REPLY"].presence || DEFAULT_HELP_REPLY
  end

  def twiml_for(body)
    escaped = ERB::Util.html_escape(body.to_s)
    <<~XML.squish
      <?xml version="1.0" encoding="UTF-8"?><Response><Message>#{escaped}</Message></Response>
    XML
  end

  private

  def assign_production_environment
    self.environment = ENVIRONMENT
  end
end
