# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "cgi"

module Discovery
  # Cost-conscious Places enrichment for Discovery.
  #
  # SOS WA already has identity + address. Places is only for missing contact/rating:
  #   1) Text Search — find placeId (cheap field mask; pick a match)
  #   2) Place Details — phone + rating (+ website; same Enterprise SKU as phone)
  #
  # Prefer V1: field masks control SKU. Avoid Atmosphere fields (reviews, editorialSummary).
  # Email is out of scope for Places — never request or return it.
  class GooglePlacesLookup
    SearchResult = Struct.new(
      :ok, :message, :api, :query, :places, :raw_search,
      keyword_init: true
    )

    DetailsResult = Struct.new(
      :ok, :message, :api, :place_id, :details, :raw_details,
      keyword_init: true
    )

    APIS = %w[legacy v1].freeze

    TEXT_SEARCH_LEGACY_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"
    DETAILS_LEGACY_URL = "https://maps.googleapis.com/maps/api/place/details/json"
    TEXT_SEARCH_V1_URL = "https://places.googleapis.com/v1/places:searchText"
    PLACE_GET_V1_URL = "https://places.googleapis.com/v1/places"

    # Legacy Details: only fields we need. Highest SKU among these is Enterprise (phone/website/rating).
    DETAILS_LEGACY_FIELDS = %w[
      place_id
      name
      formatted_phone_number
      international_phone_number
      website
      rating
      user_ratings_total
    ].join(",")

    # V1 Text Search: identity only → Pro (not Enterprise). Enough to pick a match.
    TEXT_SEARCH_V1_FIELD_MASK = [
      "places.id",
      "places.displayName",
      "places.formattedAddress"
    ].join(",")

    # V1 Details: phone + rating (+ website same Enterprise tier). No reviews / Atmosphere.
    PLACE_GET_V1_FIELD_MASK = [
      "id",
      "displayName",
      "nationalPhoneNumber",
      "internationalPhoneNumber",
      "websiteUri",
      "rating",
      "userRatingCount"
    ].join(",")

    def self.search(discovery_business:, api: :legacy)
      new(discovery_business: discovery_business, api: api).search
    end

    def self.details(discovery_business:, place_id:, api: :legacy)
      new(discovery_business: discovery_business, api: api).details(place_id)
    end

    def self.normalize_api(api)
      value = api.to_s.strip.downcase
      APIS.include?(value) ? value : "legacy"
    end

    def self.api_label(api)
      normalize_api(api) == "v1" ? "Places V1" : "Legacy"
    end

    def self.api_key
      ENV["GPLACES_KEY"].presence
    end

    def initialize(discovery_business:, api: :legacy)
      @business = discovery_business
      @api = self.class.normalize_api(api)
    end

    def search
      api_key = self.class.api_key
      return search_failure("Missing Google Places API key. Set GPLACES_KEY in .env.") if api_key.blank?

      payload = run_search(api_key)
      places = payload[:places]
      ok = !api_error?(payload)

      message =
        if api_error?(payload)
          "#{self.class.api_label(@api)} search failed: #{payload[:status]} — #{payload[:error_message]}"
        elsif places.empty?
          "No #{self.class.api_label(@api)} matches for “#{search_query}”. Pick a different query or enter Place ID manually."
        else
          "#{self.class.api_label(@api)}: found #{places.size} match#{'es' if places.size != 1}. Choose the correct business."
        end

      SearchResult.new(
        ok: ok,
        message: message,
        api: @api,
        query: search_query,
        places: places,
        raw_search: payload[:raw]
      )
    rescue StandardError => e
      search_failure("Google Places search error: #{e.message}")
    end

    def details(place_id)
      api_key = self.class.api_key
      return details_failure(place_id, "Missing Google Places API key. Set GPLACES_KEY in .env.") if api_key.blank?
      return details_failure(place_id, "Place ID is required.") if place_id.blank?

      raw = run_details(place_id, api_key)
      if details_error?(raw)
        return details_failure(
          place_id,
          "#{self.class.api_label(@api)} details failed: #{details_error_message(raw)}"
        )
      end

      normalized = normalize_details(raw)
      DetailsResult.new(
        ok: true,
        message: "#{self.class.api_label(@api)} details loaded for “#{normalized[:name].presence || place_id}”.",
        api: @api,
        place_id: normalize_place_id(place_id),
        details: normalized,
        raw_details: raw
      )
    rescue StandardError => e
      details_failure(place_id, "Google Places details error: #{e.message}")
    end

    private

    def search_failure(message)
      SearchResult.new(
        ok: false,
        message: message,
        api: @api,
        query: search_query,
        places: [],
        raw_search: nil
      )
    end

    def details_failure(place_id, message)
      DetailsResult.new(
        ok: false,
        message: message,
        api: @api,
        place_id: normalize_place_id(place_id),
        details: nil,
        raw_details: nil
      )
    end

    def search_query
      [
        @business.business_name,
        @business.city.presence || @business.filter_city,
        "WA"
      ].compact_blank.join(" ")
    end

    def run_search(api_key)
      if @api == "v1"
        normalize_v1_search(text_search_v1(api_key))
      else
        normalize_legacy_search(text_search_legacy(api_key))
      end
    end

    def run_details(place_id, api_key)
      if @api == "v1"
        place_get_v1(place_id, api_key)
      else
        place_details_legacy(place_id, api_key)
      end
    end

    def text_search_legacy(api_key)
      uri = URI(TEXT_SEARCH_LEGACY_URL)
      uri.query = URI.encode_www_form(query: search_query, key: api_key)
      get_json(uri)
    end

    def place_details_legacy(place_id, api_key)
      uri = URI(DETAILS_LEGACY_URL)
      uri.query = URI.encode_www_form(
        place_id: normalize_place_id(place_id),
        fields: DETAILS_LEGACY_FIELDS,
        key: api_key
      )
      get_json(uri)
    end

    def text_search_v1(api_key)
      uri = URI(TEXT_SEARCH_V1_URL)
      post_json(
        uri,
        headers: {
          "Content-Type" => "application/json",
          "X-Goog-Api-Key" => api_key,
          "X-Goog-FieldMask" => TEXT_SEARCH_V1_FIELD_MASK
        },
        body: { textQuery: search_query }.to_json
      )
    end

    def place_get_v1(place_id, api_key)
      uri = URI("#{PLACE_GET_V1_URL}/#{CGI.escape(normalize_place_id(place_id))}")
      uri.query = URI.encode_www_form(key: api_key)
      get_json(
        uri,
        headers: {
          "X-Goog-Api-Key" => api_key,
          "X-Goog-FieldMask" => PLACE_GET_V1_FIELD_MASK
        }
      )
    end

    def get_json(uri, headers: {})
      http_status = nil
      body = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "Foundation Discovery/1.0"
        headers.each { |key, value| request[key] = value }
        response = http.request(request)
        http_status = response.code.to_i
        response.body.to_s
      end

      parsed = JSON.parse(body)
      parsed["_http_status"] = http_status
      parsed
    rescue JSON::ParserError
      { "status" => "ERROR", "error_message" => "Invalid JSON from Google Places", "_http_status" => http_status }
    end

    def post_json(uri, headers:, body:)
      http_status = nil
      response_body = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
        request = Net::HTTP::Post.new(uri)
        request["User-Agent"] = "Foundation Discovery/1.0"
        headers.each { |key, value| request[key] = value }
        request.body = body
        response = http.request(request)
        http_status = response.code.to_i
        response.body.to_s
      end

      parsed = JSON.parse(response_body)
      parsed["_http_status"] = http_status
      parsed
    rescue JSON::ParserError
      { "error" => { "message" => "Invalid JSON from Google Places" }, "_http_status" => http_status }
    end

    def normalize_legacy_search(payload)
      # Legacy Text Search has no field mask — Google returns a fixed payload (cost less controllable).
      places = Array(payload["results"]).map do |row|
        {
          place_id: row["place_id"],
          name: row["name"],
          formatted_address: row["formatted_address"]
        }
      end

      {
        api: "legacy",
        status: payload["status"].presence || "ERROR",
        error_message: payload["error_message"],
        places: places,
        raw: payload
      }
    end

    def normalize_v1_search(payload)
      http_status = payload["_http_status"].to_i
      if http_status >= 400 || payload.dig("error", "message").present?
        return {
          api: "v1",
          status: "ERROR",
          error_message: payload.dig("error", "message") || "HTTP #{http_status}",
          places: [],
          raw: payload
        }
      end

      places = Array(payload["places"]).map do |place|
        {
          place_id: normalize_place_id(place["id"]),
          name: place.dig("displayName", "text"),
          formatted_address: place["formattedAddress"]
        }
      end

      {
        api: "v1",
        status: places.any? ? "OK" : "ZERO_RESULTS",
        error_message: nil,
        places: places,
        raw: payload
      }
    end

    def normalize_details(payload)
      if @api == "v1"
        normalize_v1_details(payload)
      else
        normalize_legacy_details(payload)
      end
    end

    def normalize_legacy_details(payload)
      result = payload["result"] || {}
      {
        place_id: result["place_id"],
        name: result["name"],
        phone: result["formatted_phone_number"].presence || result["international_phone_number"],
        website: result["website"],
        rating: result["rating"],
        user_ratings_total: result["user_ratings_total"]
      }
    end

    def normalize_v1_details(payload)
      {
        place_id: normalize_place_id(payload["id"]),
        name: payload.dig("displayName", "text"),
        phone: payload["nationalPhoneNumber"].presence || payload["internationalPhoneNumber"],
        website: payload["websiteUri"],
        rating: payload["rating"],
        user_ratings_total: payload["userRatingCount"]
      }
    end

    def normalize_place_id(id)
      id.to_s.sub(/\Aplaces\//, "")
    end

    def api_error?(search)
      status = search[:status].to_s
      status.present? && !%w[OK ZERO_RESULTS].include?(status)
    end

    def details_error?(payload)
      return true if payload.blank?
      return true if payload["_http_status"].to_i >= 400
      return true if payload.dig("error", "message").present?

      if @api == "legacy"
        status = payload["status"].to_s
        status.present? && status != "OK"
      else
        false
      end
    end

    def details_error_message(payload)
      payload.dig("error", "message").presence ||
        payload["error_message"].presence ||
        payload["status"].presence ||
        "Unknown error"
    end
  end
end
