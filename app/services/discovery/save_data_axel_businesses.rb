# frozen_string_literal: true

module Discovery
  class SaveDataAxelBusinesses
    Result = Struct.new(:created, :skipped, :skip_messages, :created_external_ids, keyword_init: true)

    def self.call(organization:, rows:, filter_city:)
      new(organization: organization, rows: rows, filter_city: filter_city).call
    end

    def initialize(organization:, rows:, filter_city:)
      @organization = organization
      @rows = Array(rows)
      @filter_city = filter_city
    end

    def call
      created = 0
      skipped = 0
      skip_messages = []
      created_external_ids = []

      @rows.each do |row|
        attrs = normalize_row(row)
        external_id = attrs.delete(:external_id)
        business_name = attrs[:business_name].presence || "This business"

        if external_id.blank?
          skipped += 1
          skip_messages << "#{business_name} skipped — missing IUSA number."
          next
        end

        existing = find_existing(external_id)
        if existing
          skipped += 1
          skip_messages << skip_message_for(existing, business_name)
          next
        end

        DiscoveryBusiness.create!(attrs.merge(
          organization: @organization,
          source: DiscoveryBusiness::SOURCE_DATA_AXEL,
          external_id: external_id,
          filter_city: normalized_filter_city,
          status: DiscoveryBusiness::STATUS_DISCOVERY
        ))
        created += 1
        created_external_ids << external_id
      end

      Result.new(
        created: created,
        skipped: skipped,
        skip_messages: skip_messages,
        created_external_ids: created_external_ids
      )
    end

    private

    def find_existing(external_id)
      DiscoveryBusiness.find_by(
        organization_id: @organization.id,
        source: DiscoveryBusiness::SOURCE_DATA_AXEL,
        external_id: external_id
      )
    end

    def skip_message_for(existing, fallback_name)
      name = existing.business_name.presence || fallback_name

      if existing.promoted?
        "\"#{name}\" is already in Potentials."
      elsif existing.archived?
        "\"#{name}\" is already captured and archived."
      else
        "\"#{name}\" is already on your Captured list."
      end
    end

    def normalized_filter_city
      Discovery::WaSosCities.normalize(@filter_city) if @filter_city.present?
    end

    def normalize_row(row)
      row = row.to_unsafe_h if row.respond_to?(:to_unsafe_h)
      row = row.stringify_keys

      city = row["City"].presence ||
             Discovery::Sources::WaSosFunnelFilters.extract_city(
               row[Discovery::Sources::WaSos::CsvParser::OFFICE_ADDRESS_COLUMN].to_s
             )

      {
        external_id: Discovery::Sources::DataAxel::CsvParser.normalize_iusa(
          row["UBI#"].presence || row["IUSA Number"]
        ),
        business_name: row["Business Name"].to_s.strip,
        business_type: row["Business Type"].to_s.strip,
        vertical_classification: Verticals.infer_from_axel(business_type: row["Business Type"]),
        office_address: row[Discovery::Sources::WaSos::CsvParser::OFFICE_ADDRESS_COLUMN].to_s.strip,
        registered_agent_name: row[Discovery::Sources::WaSos::CsvParser::REGISTERED_AGENT_NAME_COLUMN].to_s.strip,
        city: city.to_s.strip,
        phone: row["Phone Number Combined"].to_s.strip.presence,
        date_business_established: parse_established_date(row),
        raw_payload: row
      }
    end

    def parse_established_date(row)
      raw = row["date_business_established"]
      return nil if raw.blank?

      Date.parse(raw.to_s)
    rescue ArgumentError
      nil
    end
  end
end
