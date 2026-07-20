# frozen_string_literal: true

module Discovery
  module Sources
    module WaSos
      class SaveBusinesses
        Result = Struct.new(:created, :skipped, keyword_init: true)

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

          @rows.each do |row|
            attrs = normalize_row(row)
            external_id = attrs.delete(:external_id)

            if external_id.blank?
              skipped += 1
              next
            end

            if existing?(external_id)
              skipped += 1
              next
            end

            DiscoveryBusiness.create!(attrs.merge(
              organization: @organization,
              source: DiscoveryBusiness::SOURCE_WA_SOS,
              external_id: external_id,
              filter_city: normalized_filter_city,
              status: DiscoveryBusiness::STATUS_DISCOVERY
            ))
            created += 1
          end

          Result.new(created: created, skipped: skipped)
        end

        private

        def existing?(external_id)
          DiscoveryBusiness.exists?(
            organization_id: @organization.id,
            source: DiscoveryBusiness::SOURCE_WA_SOS,
            external_id: external_id
          )
        end

        def normalized_filter_city
          Cities.normalize(@filter_city) if @filter_city.present?
        end

        def normalize_row(row)
          row = row.to_unsafe_h if row.respond_to?(:to_unsafe_h)
          row = row.stringify_keys

          address = row["Office Address"].to_s

          {
            external_id: DiscoveryBusiness.normalize_ubi(row["UBI#"]),
            business_name: row["Business Name"].to_s.strip,
            business_type: row["Business Type"].to_s.strip,
            office_address: address.strip,
            registered_agent_name: row[Discovery::Sources::WaSos::CsvParser::REGISTERED_AGENT_NAME_COLUMN].to_s.strip,
            city: FunnelFilters.extract_city(address),
            raw_payload: row
          }
        end
      end
    end
  end
end
