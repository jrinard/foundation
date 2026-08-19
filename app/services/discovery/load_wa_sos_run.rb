# frozen_string_literal: true

module Discovery
  # Back-compat wrapper — use LoadDiscoveryRun for all sources.
  class LoadWaSosRun
    def self.call(run:)
      LoadDiscoveryRun.call(run: run)
    end
  end
end
