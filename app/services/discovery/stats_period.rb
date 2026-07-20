# frozen_string_literal: true

module Discovery
  # Time windows for Discovery header stats (org timezone).
  class StatsPeriod
    TODAY = "today"
    WEEK = "week"
    MONTH = "month"
    THREE_MONTHS = "3_month"
    SIX_MONTHS = "6_month"
    YEAR = "year"

    DEFAULT = TODAY

    OPTIONS = [
      [TODAY, "Today"],
      [WEEK, "Week"],
      [MONTH, "Month"],
      [THREE_MONTHS, "3 months"],
      [SIX_MONTHS, "6 months"],
      [YEAR, "Year"]
    ].freeze

    PERIODS = OPTIONS.map(&:first).freeze

    def self.normalize(value)
      PERIODS.include?(value.to_s) ? value.to_s : DEFAULT
    end

    def self.label(period)
      OPTIONS.find { |key, _| key == normalize(period) }&.last || "Today"
    end

    def self.range(period, timezone:)
      zone = ActiveSupport::TimeZone[timezone.presence] || Time.zone
      now = zone.now

      case normalize(period)
      when TODAY
        now.beginning_of_day..now.end_of_day
      when WEEK
        (now - 6.days).beginning_of_day..now.end_of_day
      when MONTH
        now.beginning_of_month..now.end_of_day
      when THREE_MONTHS
        (now - 3.months).beginning_of_day..now.end_of_day
      when SIX_MONTHS
        (now - 6.months).beginning_of_day..now.end_of_day
      when YEAR
        now.beginning_of_year..now.end_of_day
      else
        range(TODAY, timezone: timezone)
      end
    end
  end
end
