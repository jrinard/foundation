# frozen_string_literal: true

module SettingsHelper
  def auth_token_placeholder(channel)
    if channel.auth_token.present?
      "Saved — leave blank to keep"
    elsif channel.env_auth_token_present?
      "Using TWILIO_AUTH_TOKEN from ENV"
    else
      "Twilio auth token"
    end
  end

  def env_presence_label(key)
    ENV[key].present? ? "Set" : "Not set"
  end

  def outreach_section_tab_class(section)
    active = (params[:outreach_section].presence || "text_messages") == section
    ["settings-outreach-subtab", "btn", "btn-default", "settings-menu-button", ("active" if active)].compact.join(" ")
  end
end
