# frozen_string_literal: true

module Discovery
  class CreateDataAxelFile
    Result = Struct.new(:file, :errors, keyword_init: true) do
      def success?
        errors.blank? && file.present?
      end
    end

    def self.call(organization:, upload:, user: nil, label: nil)
      new(organization: organization, upload: upload, user: user, label: label).call
    end

    def initialize(organization:, upload:, user: nil, label: nil)
      @organization = organization
      @upload = upload
      @user = user
      @label = label.to_s.strip.presence
    end

    def call
      return failure("Choose a CSV file to upload.") if @upload.blank?

      raw_csv = read_upload
      return failure("Could not read the uploaded file.") if raw_csv.blank?

      filename = sanitized_filename
      row_count = count_rows(raw_csv)

      file = DiscoveryDataAxelFile.new(
        organization: @organization,
        uploaded_by_user: @user,
        filename: filename,
        label: @label,
        raw_csv: raw_csv,
        byte_size: raw_csv.bytesize,
        row_count: row_count
      )

      return Result.new(file: file, errors: file.errors.full_messages) unless file.save

      Result.new(file: file, errors: [])
    end

    private

    def read_upload
      io = @upload.respond_to?(:read) ? @upload : nil
      return nil unless io

      body = io.read.to_s
      io.rewind if io.respond_to?(:rewind)
      body.force_encoding("UTF-8").sub(/\A\uFEFF/, "")
    end

    def sanitized_filename
      name = if @upload.respond_to?(:original_filename)
               @upload.original_filename.to_s
             else
               "mountain-gems.csv"
             end
      File.basename(name).presence || "mountain-gems.csv"
    end

    def count_rows(raw_csv)
      Discovery::Sources::DataAxel::CsvParser.parse(raw_csv).size
    end

    def failure(message)
      Result.new(file: nil, errors: [message])
    end
  end
end
