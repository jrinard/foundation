# frozen_string_literal: true

class DiscoveryRun < ApplicationRecord
  include OrganizationScoped

  TRIGGER_MANUAL = "manual"
  TRIGGER_SCHEDULED = "scheduled"
  TRIGGERED_BY = [TRIGGER_MANUAL, TRIGGER_SCHEDULED].freeze

  STATUS_RUNNING = "running"
  STATUS_SUCCESS = "success"
  STATUS_EMPTY = "empty"
  STATUS_FAILED = "failed"
  STATUS_SKIPPED = "skipped"
  STATUSES = [STATUS_RUNNING, STATUS_SUCCESS, STATUS_EMPTY, STATUS_FAILED, STATUS_SKIPPED].freeze

  RECENT_WINDOW = 7.days
  RECENT_LIMIT = 50

  belongs_to :discovery_source
  belongs_to :triggered_by_user, class_name: "User", optional: true

  validates :source_key, presence: true
  validates :triggered_by, presence: true, inclusion: { in: TRIGGERED_BY }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :started_at, presence: true
  validates :row_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :recent_first, -> { order(started_at: :desc) }
  scope :recent_window, -> { where("started_at >= ?", RECENT_WINDOW.ago) }

  def reloadable?
    raw_csv.present? && [STATUS_SUCCESS, STATUS_EMPTY].include?(status)
  end

  def trigger_label
    return "Automated" if triggered_by == TRIGGER_SCHEDULED

    triggered_by_user&.name.presence || triggered_by_user&.email || "Manual"
  end

  def status_label
    {
      STATUS_RUNNING => "Running",
      STATUS_SUCCESS => "Success",
      STATUS_EMPTY => "Empty",
      STATUS_FAILED => "Failed",
      STATUS_SKIPPED => "Skipped"
    }.fetch(status, status.to_s.humanize)
  end

  def query_summary
    snap = settings_snapshot.with_indifferent_access

    case source_key
    when DiscoveryBusiness::SOURCE_DATA_AXEL
      data_axel_query_summary(snap)
    else
      wa_sos_query_summary(snap)
    end
  end

  def source_label
    Discovery::Sources::Catalog.label_for(source_key)
  end

  def duration_label
    return "—" if finished_at.blank?

    seconds = (finished_at - started_at).to_i
    return "< 1s" if seconds < 1

    if seconds < 60
      "#{seconds}s"
    else
      minutes = seconds / 60
      remainder = seconds % 60
      remainder.positive? ? "#{minutes}m #{remainder}s" : "#{minutes}m"
    end
  end

  private

  def wa_sos_query_summary(snap)
    parts = []
    if snap[:start_date].present? || snap[:end_date].present?
      parts << [snap[:start_date], snap[:end_date]].compact.join(" – ")
    end
    if snap[:business_type_id].present?
      label = business_type_label(snap[:business_type_id])
      parts << label if label.present?
    end
    if snap[:search_entity_name].present?
      parts << "\"#{snap[:search_entity_name]}\""
    end
    parts.join(" · ").presence || "—"
  end

  def data_axel_query_summary(snap)
    parts = []
    parts << "\"#{snap[:search_entity_name]}\"" if snap[:search_entity_name].present?
    if ActiveModel::Type::Boolean.new.cast(snap[:row_range_enabled])
      parts << "rows #{snap[:row_range_start]}-#{snap[:row_range_end]}"
    elsif snap[:row_limit].present?
      parts << "limit #{snap[:row_limit]}"
    end
    parts << "#{snap[:source_file_count]} files" if snap[:source_file_count].present?
    parts.join(" · ").presence || "—"
  end

  def business_type_label(type_id)
    match = Discovery::Sources::WaSos::BusinessTypes::OPTIONS.find { |_label, id| id == type_id.to_s }
    match&.first
  end
end
