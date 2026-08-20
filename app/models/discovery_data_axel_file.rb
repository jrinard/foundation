# frozen_string_literal: true

class DiscoveryDataAxelFile < ApplicationRecord
  include OrganizationScoped

  MAX_BYTE_SIZE = 50.megabytes
  MAX_LABEL_LENGTH = 120

  belongs_to :organization
  belongs_to :uploaded_by_user, class_name: "User", optional: true

  validates :filename, presence: true
  validates :label, length: { maximum: MAX_LABEL_LENGTH }, allow_blank: true
  validates :raw_csv, presence: true
  validates :byte_size, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :row_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :raw_csv_within_size_limit
  validate :raw_csv_must_be_parseable

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def human_byte_size
    ActiveSupport::NumberHelper.number_to_human_size(byte_size)
  end

  def display_label
    label.presence || default_label
  end

  def custom_label?
    label.present?
  end

  def default_label
    File.basename(filename.to_s, ".csv").presence || filename.to_s
  end

  private

  def raw_csv_within_size_limit
    return if raw_csv.blank?
    return if raw_csv.bytesize <= MAX_BYTE_SIZE

    errors.add(:raw_csv, "is too large (max #{ActiveSupport::NumberHelper.number_to_human_size(MAX_BYTE_SIZE)})")
  end

  def raw_csv_must_be_parseable
    return if raw_csv.blank?

    parsed = Discovery::Sources::DataAxel::CsvParser.parse(raw_csv)
    if parsed.empty? && raw_csv.strip.present?
      errors.add(:raw_csv, "must be a valid CSV with a header row and at least one data row")
    end
  rescue StandardError
    errors.add(:raw_csv, "must be a valid CSV file")
  end
end
