# frozen_string_literal: true

module Discovery
  module Sources
    class DataAxelSettings
      ROW_LIMIT_OPTIONS = [15, 30, 50, 100, 250, "all"].freeze
      DEFAULT_ROW_LIMIT = 15
      DEFAULT_ROW_RANGE_START = 1
      DEFAULT_ROW_RANGE_END = 15

      attr_reader :settings

      def initialize(settings = {})
        @settings = settings.to_h.stringify_keys
      end

      def row_limit
        value = settings["row_limit"].presence || DEFAULT_ROW_LIMIT
        value.to_s.downcase == "all" ? "all" : value.to_i
      end

      def row_range_enabled?
        ActiveModel::Type::Boolean.new.cast(settings["row_range_enabled"])
      end

      def row_range_start
        (settings["row_range_start"].presence || DEFAULT_ROW_RANGE_START).to_i
      end

      def row_range_end
        (settings["row_range_end"].presence || DEFAULT_ROW_RANGE_END).to_i
      end

      def filter_city
        settings["filter_city"].to_s.strip
      end

      def normalized_filter_city
        WaSos::Cities.normalize(filter_city) if filter_city.present?
      end

      def to_h
        {
          row_limit: row_limit,
          row_range_enabled: row_range_enabled?,
          row_range_start: row_range_start,
          row_range_end: row_range_end,
          filter_city: filter_city
        }
      end

      def merge(attrs)
        self.class.new(settings.merge(attrs.to_h.stringify_keys))
      end

      def to_fetch_settings(overrides = {})
        merged = settings.merge(overrides.to_h.stringify_keys)
        self.class.new(merged).to_h
      end

      def to_query(overrides = {})
        merged = to_fetch_settings(overrides)
        {
          search_entity_name: overrides[:search_entity_name].to_s.strip.presence,
          row_limit: merged[:row_limit],
          row_range_enabled: merged[:row_range_enabled],
          row_range_start: merged[:row_range_start],
          row_range_end: merged[:row_range_end],
          filter_city: merged[:filter_city]
        }.compact
      end

      def apply_row_window(rows)
        list = Array(rows)
        return list if list.empty?

        if row_range_enabled?
          start_row = row_range_start.clamp(1, list.size)
          end_row = row_range_end.clamp(start_row, list.size)
          return list[(start_row - 1)...end_row]
        end

        limit = row_limit
        return list if limit.to_s == "all"

        list.first(limit.to_i)
      end
    end
  end
end
