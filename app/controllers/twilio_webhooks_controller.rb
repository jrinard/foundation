# frozen_string_literal: true

class TwilioWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :set_current_organization

  def incoming_sms
    result = Outreach::Sms::ProcessInboundWebhook.call(
      from: params[:From],
      to: params[:To],
      body: params[:Body],
      message_sid: params[:MessageSid]
    )

    if result.twiml.present?
      render inline: result.twiml, content_type: "application/xml"
    else
      head :ok
    end
  rescue StandardError => e
    Rails.logger.error("Twilio webhook failure: #{e.class} #{e.message}")
    head :ok
  end
end
