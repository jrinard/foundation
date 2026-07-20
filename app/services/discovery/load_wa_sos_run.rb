# frozen_string_literal: true

module Discovery
  # Parses a persisted run snapshot and returns rows for the Discovery results table.
  class LoadWaSosRun
    Result = Struct.new(:run, :rows, keyword_init: true)

    def self.call(run:)
      new(run: run).call
    end

    def initialize(run:)
      @run = run
    end

    def call
      unless @run.reloadable?
        raise ArgumentError, "This run has no saved CSV to load."
      end

      rows = Sources::WaSos::CsvParser.parse(@run.raw_csv)
      Result.new(run: @run, rows: rows)
    end
  end
end
