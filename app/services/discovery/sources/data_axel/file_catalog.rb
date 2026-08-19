# frozen_string_literal: true

require "csv"

module Discovery
  module Sources
    module DataAxel
      class FileCatalog
        STORAGE_DIR = Rails.root.join("storage/discovery/data_axel")

        def self.csv_files
          paths = []
          paths.concat(Dir.glob(STORAGE_DIR.join("*.csv"))) if STORAGE_DIR.directory?
          paths.concat(Dir.glob(Rails.root.join("Summary*.csv")))
          paths.map { |path| Pathname.new(path) }.uniq.sort_by(&:basename)
        end

        def self.merged_csv_body
          files = csv_files
          return "" if files.empty?

          bodies = files.map do |path|
            path.read.force_encoding("UTF-8").sub(/\A\uFEFF/, "")
          end

          merge_csv_bodies(bodies)
        end

        def self.merge_csv_bodies(bodies)
          return "" if bodies.blank?

          merged_rows = []
          headers = nil

          bodies.each do |body|
            next if body.blank?

            table = CSV.parse(body, headers: true, liberal_parsing: true)
            next if table.headers.blank?

            headers ||= table.headers
            table.each do |row|
              merged_rows << row
            end
          end

          return "" if headers.blank?

          CSV.generate do |csv|
            csv << headers
            merged_rows.each do |row|
              csv << headers.map { |header| row[header] }
            end
          end
        end

        def self.file_count
          csv_files.size
        end

        def self.total_row_count
          body = merged_csv_body
          return 0 if body.blank?

          rows = Discovery::Sources::DataAxel::CsvParser.parse(body)
          seen = {}
          rows.count do |row|
            key = row["UBI#"].presence || row["Business Name"]
            next false if key.blank? || seen[key]

            seen[key] = true
            true
          end
        end
      end
    end
  end
end
