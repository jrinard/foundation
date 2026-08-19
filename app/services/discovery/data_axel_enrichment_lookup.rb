# frozen_string_literal: true

module Discovery
  # Search local Data Axel CSV files to enrich a captured business (phone, address, etc.).
  class DataAxelEnrichmentLookup
    MAX_RESULTS = 10

    SearchResult = Struct.new(
      :ok, :message, :query, :city_filter, :results,
      keyword_init: true
    )

    DetailsResult = Struct.new(
      :ok, :message, :details,
      keyword_init: true
    )

    def self.search(discovery_business:)
      new(discovery_business).search
    end

    def self.details(discovery_business:, iusa:)
      new(discovery_business).details(iusa: iusa)
    end

    def initialize(discovery_business)
      @business = discovery_business
    end

    def search
      query = search_text
      return search_failure("Missing business name for #{GemSources.label_for(DiscoveryBusiness::SOURCE_DATA_AXEL)} lookup.") if query.blank?

      rows = load_rows
      return search_failure("No #{GemSources.label_for(DiscoveryBusiness::SOURCE_DATA_AXEL)} data files found in storage.") if rows.empty?

      ranked = rank_rows(rows, query)
      display_results = narrow_to_ubi_matches(ranked).first(MAX_RESULTS)
      city = city_filter

      gem_label = GemSources.label_for(DiscoveryBusiness::SOURCE_DATA_AXEL)
      empty_message =
        if city.present?
          "No #{gem_label} matches for “#{query}” (city on file: #{city.titleize})."
        else
          "No #{gem_label} matches for “#{query}”."
        end

      SearchResult.new(
        ok: true,
        message: display_results.empty? ? empty_message : nil,
        query: query,
        city_filter: city,
        results: display_results.map { |row| serialize_result(row) }
      )
    rescue StandardError => e
      search_failure("#{GemSources.label_for(DiscoveryBusiness::SOURCE_DATA_AXEL)} lookup failed: #{e.message}")
    end

    def details(iusa:)
      iusa = Discovery::Sources::DataAxel::CsvParser.normalize_iusa(iusa)
      return details_failure("Missing IUSA number.") if iusa.blank?

      row = load_rows.find { |candidate| Discovery::Sources::DataAxel::CsvParser.normalize_iusa(candidate["UBI#"]) == iusa }
      return details_failure("#{GemSources.label_for(DiscoveryBusiness::SOURCE_DATA_AXEL)} record not found for IUSA #{iusa}.") if row.blank?

      DetailsResult.new(
        ok: true,
        message: nil,
        details: serialize_details(row)
      )
    rescue StandardError => e
      details_failure("#{GemSources.label_for(DiscoveryBusiness::SOURCE_DATA_AXEL)} details failed: #{e.message}")
    end

    private

    def search_text
      @business.business_name.to_s.strip
    end

    def city_filter
      @business.display_city.to_s.strip.downcase.presence
    end

    def our_ubi
      DiscoveryBusiness.normalize_ubi(@business.display_ubi)
    end

    def load_rows
      body = Sources::DataAxel::FileCatalog.merged_csv_body
      return [] if body.blank?

      Sources::DataAxel::CsvParser.parse(body)
    end

    def rank_rows(rows, query)
      query_norm = normalize_name(query)

      rows
        .select { |row| candidate_matches?(row, query_norm) }
        .sort_by { |row| -score_row(row, query_norm) }
    end

    def candidate_matches?(row, query_norm)
      iusa = Discovery::Sources::DataAxel::CsvParser.normalize_iusa(row["UBI#"])
      return true if our_ubi.present? && iusa == our_ubi

      name_candidates(row).any? { |name| name_matches?(name, query_norm) }
    end

    def name_candidates(row)
      [row["Business Name"], row["Legal Name"], row["Company Name"]]
        .map { |value| normalize_name(value) }
        .reject(&:blank?)
        .uniq
    end

    def name_matches?(candidate, query_norm)
      return false if candidate.blank? || query_norm.blank?

      return true if candidate == query_norm
      return true if candidate.include?(query_norm) || query_norm.include?(candidate)

      query_words = query_norm.split
      candidate_words = candidate.split
      return false if query_words.empty? || candidate_words.empty?

      overlap = (query_words & candidate_words).size
      overlap >= 2 || (query_words.size == 1 && overlap == 1)
    end

    def score_row(row, query_norm)
      score = 0
      iusa = Discovery::Sources::DataAxel::CsvParser.normalize_iusa(row["UBI#"])
      score += 1000 if our_ubi.present? && iusa == our_ubi

      name_candidates(row).each do |name|
        score += 500 if name == query_norm
        score += 300 if name.include?(query_norm) || query_norm.include?(name)
        score += ((query_norm.split & name.split).size * 25)
      end

      row_city = row["City"].to_s.strip.downcase
      score += 100 if city_filter.present? && row_city == city_filter
      score += 10 if row["Phone Number Combined"].present?

      score
    end

    def narrow_to_ubi_matches(rows)
      return rows if our_ubi.blank?

      ubi_matches = rows.select do |row|
        Discovery::Sources::DataAxel::CsvParser.normalize_iusa(row["UBI#"]) == our_ubi
      end
      ubi_matches.presence || rows
    end

    def serialize_result(row)
      iusa = Discovery::Sources::DataAxel::CsvParser.normalize_iusa(row["UBI#"])
      {
        iusa: iusa,
        business_name: row["Business Name"].to_s,
        legal_name: row["Legal Name"].to_s,
        office_address: row["Office Address"].to_s,
        phone: row["Phone Number Combined"].to_s,
        business_type: row["Business Type"].to_s,
        registered_agent_name: row["Reg Name"].to_s,
        city: row["City"].to_s,
        ubi_match: our_ubi.present? && iusa == our_ubi
      }
    end

    def serialize_details(row)
      business_type = row["Business Type"].to_s
      serialize_result(row).merge(
        date_business_established: row["date_business_established"],
        vertical_classification: Verticals.infer_from_axel(business_type: business_type)
      )
    end

    def normalize_name(value)
      value.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").squeeze(" ").strip
    end

    def search_failure(message)
      SearchResult.new(ok: false, message: message, query: search_text, city_filter: city_filter, results: [])
    end

    def details_failure(message)
      DetailsResult.new(ok: false, message: message, details: nil)
    end
  end
end
