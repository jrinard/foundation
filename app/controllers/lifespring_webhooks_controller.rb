# frozen_string_literal: true

class LifespringWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :set_current_organization

  before_action :require_webhook_token!

  def contact_form_opt_in
    result = Lifespring::ContactFormOptIn.call(payload: permitted_payload)

    if result.success?
      render json: {
        ok: true,
        customer_id: result.customer.id,
        created: result.created,
        board: "prospects",
        sms_opt_in: result.customer.sms_opted_in?,
        sms_opt_in_at: result.customer.sms_opt_in_at&.iso8601,
        sms_opt_in_source: result.customer.sms_opt_in_source
      }, status: :ok
    else
      render json: { ok: false, error: result.error }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("LifeSpring contact form opt-in error: #{e.class} #{e.message}")
    render json: { ok: false, error: "Internal error." }, status: :internal_server_error
  end

  private

  def require_webhook_token!
    expected = ENV["LIFESPRING_CONTACT_FORM_WEBHOOK_TOKEN"].to_s
    return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, webhook_token.to_s)

    render json: { ok: false, error: "Unauthorized" }, status: :unauthorized
  end

  def webhook_token
    auth = request.headers["Authorization"].to_s
    return Regexp.last_match(1) if auth.match(/\ABearer (.+)\z/i)

    request.headers["X-LifeSpring-Webhook-Token"].presence
  end

  def permitted_payload
    params.permit(
      :name,
      :business_name,
      :email,
      :phone,
      :message,
      :sms_opt_in,
      :sms_opt_in_source,
      :sms_opt_in_at,
      :sms_opt_in_label
    ).to_h
  end
end
