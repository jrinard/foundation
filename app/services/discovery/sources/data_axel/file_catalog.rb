# frozen_string_literal: true

require "csv"

module Discovery
  module Sources
    module DataAxel
      class FileCatalog
        def self.for(organization)
          new(organization)
        end

        def initialize(organization)
          @organization = organization
        end

        def files
          @files ||= DiscoveryDataAxelFile.where(organization_id: @organization.id).order(:id).to_a
        end

        def csv_files
          files
        end

        def merged_csv_body
          bodies = files.map { |file| normalize_body(file.raw_csv) }
          self.class.merge_csv_bodies(bodies)
        end

        def file_count
          files.size
        end

        def total_row_count
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

        private

        def normalize_body(body)
          body.to_s.dup.force_encoding("UTF-8").sub(/\A\uFEFF/, "")
        end
      end
    end
  end
end
