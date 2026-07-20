# frozen_string_literal: true

module Discovery
  module Sources
    class WaSosSettings
      DEFAULTS = {
        "business_type_id" => "65",
        "active_only" => true,
        "date_cadence" => Discovery::Sources::WaSos::DateCadence::DEFAULT,
        "filter_city" => "Vancouver"
      }.freeze

      KEYS = DEFAULTS.keys.freeze

      def self.from_organization(organization)
        new(
          "business_type_id" => organization.discovery_wa_sos_business_type_id,
          "active_only" => organization.discovery_wa_sos_active_only,
          "date_cadence" => organization.discovery_wa_sos_date_cadence,
          "filter_city" => organization.discovery_wa_sos_city
        )
      end

      def initialize(raw = {})
        @raw = DEFAULTS.merge(raw.to_h.stringify_keys.slice(*KEYS))
      end

      def to_h
        @raw.dup
      end

      def merge(attrs)
        self.class.new(@raw.merge(attrs.to_h.stringify_keys.slice(*KEYS)))
      end

      def business_type_id
        @raw["business_type_id"].presence || DEFAULTS["business_type_id"]
      end

      def active_only
        ActiveModel::Type::Boolean.new.cast(@raw["active_only"])
      end

      def date_cadence
        cadence = @raw["date_cadence"].presence || DEFAULTS["date_cadence"]
        Discovery::Sources::WaSos::DateCadence.valid?(cadence) ? cadence : DEFAULTS["date_cadence"]
      end

      def filter_city
        @raw["filter_city"].presence || DEFAULTS["filter_city"]
      end

      def normalized_filter_city
        Discovery::Sources::WaSos::Cities.normalize(filter_city)
      end

      def date_range(now: Time.zone.now)
        Discovery::Sources::WaSos::DateCadence.date_range(date_cadence, now: now)
      end

      def to_sos_query(overrides = {})
        cadence = resolved_cadence(overrides[:date_cadence])
        default_start, default_end = Discovery::Sources::WaSos::DateCadence.date_range(cadence)
        search_name = overrides[:search_entity_name].to_s.strip

        start_date = overrides[:start_date].presence || default_start
        end_date = overrides[:end_date].presence || default_end

        if search_name.present?
          start_date = "01/01/2000"
          end_date = default_end
        end

        query = {
          business_type_id: overrides[:business_type_id].presence || business_type_id,
          business_status_id: "1",
          start_date: start_date,
          end_date: end_date
        }
        query[:search_entity_name] = search_name if search_name.present?
        query
      end

      def to_fetch_settings(overrides = {})
        cadence = resolved_cadence(overrides[:date_cadence])
        default_start, default_end = date_range

        {
          business_type_id: overrides[:business_type_id].presence || business_type_id,
          date_cadence: cadence,
          start_date: overrides[:start_date].presence || default_start,
          end_date: overrides[:end_date].presence || default_end
        }
      end

      private

      def resolved_cadence(override)
        cadence = override.presence || date_cadence
        Discovery::Sources::WaSos::DateCadence.valid?(cadence) ? cadence : date_cadence
      end
    end
  end
end
