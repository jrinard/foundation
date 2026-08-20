# frozen_string_literal: true

namespace :discovery do
  desc "Import CSV files from storage/discovery/data_axel into DB for an org (ORG_SLUG=lifespring)"
  task import_data_axel_files_from_disk: :environment do
    slug = ENV.fetch("ORG_SLUG", "lifespring")
    org = Organization.find_by!(slug: slug)
    dir = Rails.root.join("storage/discovery/data_axel")

    unless dir.directory?
      abort "No directory at #{dir} — nothing to import."
    end

    paths = Dir.glob(dir.join("*.csv")).sort
    if paths.empty?
      abort "No CSV files in #{dir}."
    end

    Current.organization = org
    imported = 0

    paths.each do |path|
      filename = File.basename(path)
      next if org.discovery_data_axel_files.exists?(filename: filename)

      raw_csv = File.read(path).force_encoding("UTF-8").sub(/\A\uFEFF/, "")
      row_count = Discovery::Sources::DataAxel::CsvParser.parse(raw_csv).size

      org.discovery_data_axel_files.create!(
        filename: filename,
        raw_csv: raw_csv,
        byte_size: raw_csv.bytesize,
        row_count: row_count
      )
      imported += 1
      puts "Imported #{filename} (#{row_count} rows)"
    end

    puts "Done — #{imported} new file(s) for #{org.name}."
  end
end
