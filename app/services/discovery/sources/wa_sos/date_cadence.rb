# frozen_string_literal: true

module Discovery
  module Sources
    module WaSos
      module DateCadence
        DEFAULT = "24h"

        OPTIONS = {
          "24h" => "Last 24 hours",
          "1week" => "1 week",
          "1month" => "1 month"
        }.freeze

        def self.valid?(cadence)
          OPTIONS.key?(cadence.to_s)
        end

        def self.date_range(cadence, now: Time.zone.now)
          start_time = case cadence.to_s
                       when "1week" then now - 1.week
                       when "1month" then now - 1.month
                       else now - 24.hours
                       end

          [start_time.strftime("%m/%d/%Y"), now.strftime("%m/%d/%Y")]
        end
      end
    end
  end
end
