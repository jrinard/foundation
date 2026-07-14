class QuickbooksService
  attr_reader :oauth_client, :integration, :context

  def initialize(context = nil)
    @context = context
    @integration = context&.integration || QuickbooksToken.integration_for(Current.organization)
    @environment = @integration&.environment || "sandbox"
    @oauth_client = build_oauth_client(@environment)
  end

  def get_authorization_url(context = nil)
    _context = context || @context
    redirect_uri = oauth_redirect_uri

    oauth_client.auth_code.authorize_url(
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: "com.intuit.quickbooks.accounting",
      state: oauth_state,
      locale: "en-us"
    )
  end

  def fetch_and_store_access_token(auth_code, context = nil, realm_id: nil)
    token = oauth_client.auth_code.get_token(
      auth_code,
      redirect_uri: oauth_redirect_uri,
      headers: { "CSRFToken" => oauth_state }
    )

    store_token(token, realm_id: realm_id)
  end

  def refresh_token_force(context = nil)
    token_record = integration_record
    return nil unless token_record&.access_token.present?

    access_token = OAuth2::AccessToken.new(
      oauth_client,
      token_record.access_token,
      refresh_token: token_record.refresh_token
    )

    begin
      refreshed_token = access_token.refresh!
      update_token_in_db(refreshed_token)
    rescue OAuth2::Error => e
      Rails.logger.warn("QuickBooks token refresh failed: #{e.message}")
    end

    token_record.reload
  end

  def refresh_token_if_expired
    token_record = integration_record
    return nil unless token_record&.access_token.present?

    if token_record.expires_at.present? && Time.current > token_record.expires_at
      access_token = OAuth2::AccessToken.new(
        oauth_client,
        token_record.access_token,
        refresh_token: token_record.refresh_token
      )

      begin
        refreshed_token = access_token.refresh!
        update_token_in_db(refreshed_token)
      rescue OAuth2::Error => e
        Rails.logger.warn("QuickBooks token refresh failed: #{e.message}")
      end
    end

    token_record.reload
  end

  def fetch_salesreceipts_for_customer(qbCustomerID, context = nil)
    api_get_collection(qbCustomerID, "SalesReceipt")
  end

  def fetch_invoices_for_customer(qbCustomerID, context = nil)
    api_get_collection(qbCustomerID, "Invoice")
  end

  def fetch_refundreceipts_for_customer(qbCustomerID, context = nil)
    api_get_collection(qbCustomerID, "RefundReceipt")
  end

  def fetch_customer_by_display_name(display_name, context = nil)
    refresh_token_if_expired
    token_record = integration_record
    return nil unless token_record&.access_token.present?

    sanitized_name = display_name.gsub("'", "''")
    query_value = URI.encode_www_form_component("SELECT * FROM Customer WHERE DisplayName = '#{sanitized_name}'")
    url = "#{api_base_url}/query?minorversion=73&query=#{query_value}"

    response = RestClient.get(url, authorization_headers(token_record))
    customer_data = JSON.parse(response.body)
    customer_data.dig("QueryResponse", "Customer")&.first
  rescue RestClient::Unauthorized, RestClient::Forbidden => e
    parse_qb_error(e)
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.warn("QuickBooks customer lookup failed: #{e.message}")
    nil
  end

  def fetch_pdf_invoice(qbInvoiceID, context = nil, sales_receipt, docNumber)
    refresh_token_if_expired
    token_record = integration_record
    return nil unless token_record&.access_token.present?

    invoice_type = case sales_receipt
                     when "sales_receipt" then "salesreceipt"
                     when "refund_receipt" then "refundreceipt"
                     else "invoice"
                     end

    pdf_url = "#{api_base_url}/#{invoice_type}/#{qbInvoiceID}/pdf?minorversion=73"
    response = RestClient.get(pdf_url, authorization_headers(token_record).merge(Accept: "application/pdf"))
    filename = "#{invoice_type}_#{docNumber}.pdf"
    [response.body.force_encoding("BINARY"), filename, nil]
  rescue RestClient::Unauthorized, RestClient::Forbidden
    "Unauthorized access"
  rescue RestClient::ExceptionWithResponse => e
    "API error: #{e.message}"
  end

  private

  def integration_record
    @integration || context&.integration || QuickbooksToken.integration_for(Current.organization)
  end

  def sandbox?
    @environment == "sandbox"
  end

  def build_oauth_client(environment)
    if environment == "sandbox"
      OAuth2::Client.new(
        ENV["QB_CLIENT_ID"],
        ENV["QB_CLIENT_SECRET"],
        site: "https://sandbox-quickbooks.api.intuit.com",
        authorize_url: "https://appcenter.intuit.com/connect/oauth2",
        token_url: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
      )
    else
      OAuth2::Client.new(
        ENV["QB_CLIENT_ID_PRO"],
        ENV["QB_CLIENT_SECRET_PRO"],
        site: "https://api.intuit.com",
        authorize_url: "https://appcenter.intuit.com/connect/oauth2",
        token_url: "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
      )
    end
  end

  def oauth_redirect_uri
    sandbox? ? ENV["QB_REDIRECT_URI"] : ENV["QB_REDIRECT_URI_PRO"]
  end

  def oauth_state
    org_id = integration_record&.organization_id || Current.organization_id
    "FOUNDATION-#{org_id}"
  end

  def api_base_url
    realm = integration_record&.effective_realm_id
    raise ArgumentError, "QuickBooks realm_id is not configured for #{Current.organization&.name}" if realm.blank?

    host = sandbox? ? "https://sandbox-quickbooks.api.intuit.com" : "https://quickbooks.api.intuit.com"
    "#{host}/v3/company/#{realm}"
  end

  def authorization_headers(token_record)
    { Authorization: "Bearer #{token_record.access_token}", Accept: "application/json" }
  end

  def api_get_collection(qb_customer_id, entity_name)
    refresh_token_if_expired
    token_record = integration_record
    return nil unless token_record&.access_token.present?

    query_value = URI.encode_www_form_component("SELECT * FROM #{entity_name} WHERE CustomerRef = '#{qb_customer_id}'")
    url = "#{api_base_url}/query?minorversion=73&query=#{query_value}"

    response = RestClient.get(url, authorization_headers(token_record))
    data = JSON.parse(response.body)
    records = data.dig("QueryResponse", entity_name)
    return "No #{entity_name} found" if records.nil?

    records
  rescue RestClient::Unauthorized, RestClient::Forbidden
    "Unauthorized access"
  rescue RestClient::ExceptionWithResponse => e
    "API error: #{e.message}"
  end

  def parse_qb_error(error)
    error_response = JSON.parse(error.response) rescue {}
    error_response.dig("fault", "error", 0, "message") || "Authentication error occurred."
  end

  def store_token(token, realm_id: nil)
    record = integration_record || QuickbooksToken.integration_for(Current.organization)

    record.update!(
      access_token: token.token,
      refresh_token: token.refresh_token,
      expires_at: Time.current + token.expires_in.to_i.seconds,
      active: true
    )

    record.apply_realm_from_oauth!(realm_id) if realm_id.present?
    @integration = record
  end

  def update_token_in_db(refreshed_token)
    record = integration_record
    return unless record

    record.update!(
      access_token: refreshed_token.token,
      refresh_token: refreshed_token.refresh_token,
      expires_at: Time.current + refreshed_token.expires_in.to_i.seconds,
      active: true
    )
  end
end
