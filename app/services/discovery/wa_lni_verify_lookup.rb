# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "cgi"

module Discovery
  # WA L&I Verify a Contractor — search + business details (phone, address, owners).
  # Public endpoints used by https://secure.lni.wa.gov/verify/
  class WaLniVerifyLookup
    BASE_URL = "https://secure.lni.wa.gov/verify"
    SEARCH_URL = "#{BASE_URL}/Controller.aspx/Search".freeze
    DETAILS_URL = "#{BASE_URL}/Controller.aspx/GetBusinessDetails".freeze

    SearchResult = Struct.new(
      :ok, :message, :query, :city_filter, :search_by, :results, :raw_search,
      keyword_init: true
    )

    DetailsResult = Struct.new(
      :ok, :message, :details, :raw_details,
      keyword_init: true
    )

    def self.search(discovery_business:)
      new(discovery_business).search
    end

    def self.details(ubi:, license:)
      new(nil).details(ubi: ubi, license: license)
    end

    def initialize(discovery_business)
      @business = discovery_business
    end

    def search
      query = search_text
      return search_failure("Missing business name for L&I search.") if query.blank?

      payload = post_json(SEARCH_URL, search_payload(query))
      raw_results = payload.dig("d", "SearchResult") || []
      ranked = rank_results(raw_results.reject { |row| inactive_result?(row) })
      display_results = narrow_to_ubi_matches(ranked)
      city = city_filter
      empty_message =
        if city.present?
          "No active L&I matches for “#{query}” (city on file: #{city.titleize})."
        else
          "No active L&I matches for “#{query}”."
        end

      SearchResult.new(
        ok: true,
        message: display_results.empty? ? empty_message : nil,
        query: query,
        city_filter: city,
        search_by: :name,
        results: display_results.map { |row| serialize_result(row) },
        raw_search: payload
      )
    rescue StandardError => e
      search_failure("L&I search failed: #{e.message}")
    end

    def details(ubi:, license:)
      ubi = ubi.to_s.gsub(/\D/, "")
      license = license.to_s.strip
      return details_failure("Missing UBI or license number.") if ubi.blank? || license.blank?

      payload = post_json(DETAILS_URL, details_payload(ubi: ubi, license: license))
      return_value = payload.dig("d", "ReturnValue") || {}
      contractor = return_value["Contractor"] || {}

      if contractor.blank?
        return details_failure("L&I returned no contractor details.")
      end

      DetailsResult.new(
        ok: true,
        message: nil,
        details: serialize_details(return_value),
        raw_details: payload
      )
    rescue StandardError => e
      details_failure("L&I details failed: #{e.message}")
    end

    private

    def search_text
      @business.business_name.to_s.strip
    end

    def search_payload(query)
      {
        dtoSrch: {
          firstSearch: 1,
          searchCat: "Name",
          searchText: query,
          Name: query,
          pageNumber: 0,
          SearchType: 2,
          SortColumn: "Rank",
          SortOrder: "desc",
          pageSize: 10,
          ContractorTypeFilter: [],
          SessionID: "",
          SAW: ""
        }
      }
    end

    def city_filter
      @business.display_city.to_s.strip.upcase.presence
    end

    def details_payload(ubi:, license:)
      {
        ubi: ubi,
        license: license,
        irlVilationId: "",
        isSecured: false
      }
    end

    def post_json(url, body)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 20

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json; charset=UTF-8"
      request["Accept"] = "application/json"
      request.body = body.to_json

      response = http.request(request)
      raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def rank_results(rows)
      our_ubi = DiscoveryBusiness.normalize_ubi(@business.display_ubi)
      our_city = city_filter
      query = search_text.downcase

      rows.sort_by do |row|
        score = row["OverallRank"].to_i
        score -= 1000 if DiscoveryBusiness.normalize_ubi(row["Ubi"]) == our_ubi && our_ubi.present?
        score -= 100 if row["City"].to_s.strip.upcase == our_city && our_city.present?
        score -= 200 if row["BusinessName"].to_s.strip.casecmp(query).zero?
        score
      end
    end

    def inactive_result?(row)
      row["Status"].to_s.strip.casecmp("inactive").zero?
    end

    def narrow_to_ubi_matches(rows)
      our_ubi = DiscoveryBusiness.normalize_ubi(@business.display_ubi)
      return rows if our_ubi.blank?

      ubi_matches = rows.select { |row| DiscoveryBusiness.normalize_ubi(row["Ubi"]) == our_ubi }
      ubi_matches.presence || rows
    end

    def serialize_result(row)
      ubi = row["Ubi"].to_s
      license_id = row["LicenseId"].to_s
      {
        ubi: ubi,
        license_id: license_id,
        business_name: row["BusinessName"].to_s,
        contractor_type: row["ContractorType"].to_s,
        contractor_group: row["ContractorGroup"].to_s,
        city: row["City"].to_s,
        state: row["State"].to_s,
        zip_code: row["ZipCode"].to_s,
        status: row["Status"].to_s,
        ubi_match: DiscoveryBusiness.normalize_ubi(ubi) == DiscoveryBusiness.normalize_ubi(@business.display_ubi),
        detail_url: detail_page_url(ubi: ubi, license_id: license_id)
      }
    end

    def serialize_details(return_value)
      contractor = return_value["Contractor"] || {}
      employer = return_value["Employer"] || {}
      ubi = contractor["UbiNumber"].to_s
      license_id = contractor["LicenseNumber"].to_s
      owners = Array(contractor["BusinesOwners"]).map do |owner|
        {
          name: owner["Name"].to_s,
          role: owner["RoleDescription"].to_s
        }
      end

      specialty = contractor["SpecialtyName1"].to_s.presence
      license_type = contractor["LicenseType"].to_s.presence
      vertical = Discovery::Verticals.infer_from_lni(
        specialty: specialty,
        license_type: license_type
      )

      {
        phone: format_phone(contractor["PhoneNumber"]),
        business_name: contractor["BusinessName"].to_s,
        parent_company: contractor["ParentCompany"].to_s,
        dba_name: employer_dba_name(employer),
        license_number: license_id,
        ubi: ubi,
        license_type: license_type.to_s,
        specialty: specialty,
        vertical_classification: vertical,
        vertical_source: [specialty, license_type].compact.join(" · ").presence,
        status: contractor["StatusDescription"].to_s,
        address: compact_address(
          contractor["Address1"],
          contractor["Address2"],
          contractor["City"],
          contractor["State"],
          contractor["Zip"]
        ),
        owners: owners,
        employer_rep: employer_account_rep(employer),
        detail_url: detail_page_url(ubi: ubi, license_id: license_id)
      }
    end

    def employer_dba_name(employer)
      employer.dig("EmployerDetails", 0, "AccountInfoBusinessNameList", 0, "BusinessDbaName").to_s.presence
    end

    def employer_account_rep(employer)
      employer.dig("EmployerDetails", 0, "AccountInfoStatusList", 0, "AccountRepresentative").to_s.presence
    end

    def format_phone(value)
      digits = value.to_s.gsub(/\D/, "")
      return value.to_s.strip if digits.length != 10

      "(#{digits[0, 3]}) #{digits[3, 3]}-#{digits[6, 4]}"
    end

    def compact_address(line1, line2, city, state, zip)
      parts = [line1, line2, [city, state].compact_blank.join(", "), zip].flatten.compact_blank
      parts.join(", ").presence
    end

    def detail_page_url(ubi:, license_id:)
      return if ubi.blank?

      query = ["UBI=#{CGI.escape(ubi)}"]
      query << "LIC=#{CGI.escape(license_id)}" if license_id.present?
      query << "SAW="
      "#{BASE_URL}/Detail.aspx?#{query.join('&')}"
    end

    def search_failure(message)
      SearchResult.new(
        ok: false,
        message: message,
        query: search_text,
        city_filter: city_filter,
        search_by: :name,
        results: [],
        raw_search: nil
      )
    end

    def details_failure(message)
      DetailsResult.new(
        ok: false,
        message: message,
        details: nil,
        raw_details: nil
      )
    end
  end
end
