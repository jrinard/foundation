# frozen_string_literal: true

module Discovery
  # Live preview of gap-based opportunity score (what we can sell).
  #
  # Three sell pillars (triangle):
  #   1. Website — landing page, branding
  #   2. Reputation — Google Places, reviews, ratings
  #   3. Social & listings — Facebook/LinkedIn, directories / online indexes
  #
  # Row display (package total still sums gap sell points only):
  #   unchecked → 0, red — not reviewed yet
  #   gap (checked, missing/weak) → +sell points (e.g. +50 website, +25 brand)
  #   ok (checked, present/strong) → check icon, green — reviewed, no sell gap
  class OpportunityScorePreview
    Line = Struct.new(:key, :label, :points, :status, :detail, keyword_init: true) do
      def awarded?
        status == :gap
      end

      def checked?
        status == :ok
      end

      def display_points_label
        case status
        when :unchecked then "0"
        when :gap then "+#{points}"
        else "0"
        end
      end

      # Back-compat
      def awarded
        awarded?
      end
    end

    Pillar = Struct.new(:key, :label, :blurb, :lines, :groups, :total, :max_total, :unchecked_count, :color, keyword_init: true) do
      def analyzed?
        unchecked_count.to_i.zero?
      end
    end

    Group = Struct.new(:key, :label, :lines, :total, :max_total, :unchecked_count, keyword_init: true) do
      def analyzed?
        unchecked_count.to_i.zero?
      end
    end

    # Clockwise from top of donut: Social (top right) → Foundation (bottom) → Reputation (top left)
    DONUT_SEGMENTS = [
      { key: :social, short_label: "Social", color: "#5e3572" },
      { key: :website, short_label: "Foundation", color: "#465184" },
      { key: :reputation, short_label: "Reputation", color: "#923f78" }
    ].freeze
    PILLAR_COLORS = DONUT_SEGMENTS.to_h { |segment| [segment[:key], segment[:color]] }.freeze
    DONUT_MUTED = "#c5cdd6"
    DONUT_PARTS = {
      website: [
        { key: :weak_brand, label: "Logo" },
        { key: :no_website, label: "Website" },
        { key: :hosting_maintenance, label: "Hosting" }
      ],
      reputation: [
        { key: :no_places, label: "Places" },
        { key: :weak_reviews, label: "Reviews" }
      ],
      social: [
        { key: :no_facebook, label: "Facebook" },
        { key: :no_linkedin, label: "LinkedIn" }
      ]
    }.freeze
    STATUS_UNCHECKED = "unchecked"
    STATUS_FOUND = "found"
    STATUS_MISSING = "missing"

    PILLARS = [
      {
        key: :website,
        label: "Foundation",
        blurb: "",
        groups: [
          {
            key: :foundation,
            label: "Identity and Landing",
            rules: [
              { key: :weak_brand, label: "Logo / brand", points: 50 },
              { key: :no_website, label: "Website", points: 50 },
              { key: :hosting_maintenance, label: "Hosting & Maintenance", points: 25 }
            ]
          }
        ]
      },
      {
        key: :reputation,
        label: "Reputation",
        blurb: "Google Places, reviews, ratings",
        rules: [
          { key: :no_places, label: "Google Places match", points: 25 },
          { key: :weak_reviews, label: "Google reviews / rating", points: 50 }
        ]
      },
      {
        key: :social,
        label: "Social & listings",
        blurb: "Social presence + directories they should be listed in",
        rules: [
          { key: :no_facebook, label: "Facebook page", points: 15 },
          { key: :no_linkedin, label: "LinkedIn page", points: 10 }
        ]
      }
    ].freeze

    FIT_RULES = [
      { key: :contact_phone, label: "Phone number", points: 100 },
      { key: :contact_email, label: "Email", points: 100 },
      { key: :new_business, label: "New / recently captured", points: 100 }
    ].freeze
    CONTACT_OUTREACH_POINTS = 100
    CONTACT_FIT_KEYS = %i[contact_phone contact_email].freeze
    NEW_BUSINESS_WINDOW = 30.days
    NEW_BUSINESS_FRESH_WINDOW = 14.days
    NEW_BUSINESS_MID_POINTS = 50
    REVIEWS_FEW_THRESHOLD = 3
    REVIEWS_LOW_THRESHOLD = 10
    REVIEWS_MID_THRESHOLD = 50
    REVIEWS_FEW_POINTS = 50
    REVIEWS_LOW_POINTS = 25
    REVIEWS_MID_POINTS = 15
    FOUNDATION_REFRESH_RATIO = 0.5

    def self.call(discovery_business:)
      new(discovery_business: discovery_business).call
    end

    def initialize(discovery_business:)
      @business = discovery_business
    end

    def call
      pillars = PILLARS.map { |pillar| build_pillar(pillar) }
      pillars_by_key = pillars.index_by(&:key)
      fit_lines = FIT_RULES.map { |rule| build_fit_line(rule) }
      fit_total = fit_lines.reject { |line| CONTACT_FIT_KEYS.include?(line.key) }.select(&:awarded?).sum(&:points) +
        contact_outreach_points
      fit_max = FIT_RULES.sum { |rule| rule[:points] } - CONTACT_OUTREACH_POINTS

      package_total = pillars.sum(&:total)
      package_max = pillars.sum(&:max_total)
      unchecked_total = pillars.sum(&:unchecked_count)
      analyzed_count = pillars.count(&:analyzed?)
      opportunity_summary = build_opportunity_summary(pillars, fit_total, package_total + fit_total, package_max + fit_max)

      donut_segments = build_donut_segments(pillars_by_key)
      donut_parts = donut_segments.flat_map { |segment| segment[:parts] }

      result = {
        pillars: pillars,
        donut_segments: donut_segments,
        donut_progress: {
          accounted: donut_parts.count { |part| part[:accounted] },
          total: donut_parts.size,
          pillars_accounted: donut_segments.count { |segment| segment[:analyzed] },
          pillars_total: donut_segments.size
        },
        analyzed_count: analyzed_count,
        analyzed_max: pillars.size,
        fit_lines: fit_lines,
        fit_total: fit_total,
        fit_max: fit_max,
        package_total: package_total,
        package_max: package_max,
        unchecked_total: unchecked_total,
        total: package_total + fit_total,
        max_total: package_max + fit_max,
        opportunity_summary: opportunity_summary,
        lines: pillars.flat_map(&:lines) + fit_lines
      }
      result[:capture_summary] = Discovery::OpportunityCaptureSummary.call(
        discovery_business: @business,
        score_preview: result
      )
      result
    end

    private

    def build_donut_segments(pillars_by_key)
      DONUT_SEGMENTS.map do |seg|
        pillar = pillars_by_key[seg[:key]]
        lines_by_key = donut_lines_by_key(pillar)

        parts = DONUT_PARTS.fetch(seg[:key], []).map do |part_def|
          line = lines_by_key[part_def[:key]]
          accounted = line.present? && line.status != :unchecked
          {
            key: part_def[:key],
            label: part_def[:label],
            accounted: accounted
          }
        end

        analyzed = parts.present? && parts.all? { |part| part[:accounted] }

        {
          key: seg[:key],
          label: seg[:short_label],
          analyzed: analyzed,
          color: seg[:color],
          has_gap: pillar&.total.to_i.positive?,
          parts: parts
        }
      end
    end

    def donut_lines_by_key(pillar)
      return {} if pillar.blank?

      lines = pillar.groups.present? ? pillar.groups.flat_map(&:lines) : pillar.lines
      lines.index_by(&:key)
    end

    def build_opportunity_summary(pillars, fit_total, total, max_total)
      labels = pillars.select { |pillar| pillar.total.to_i.positive? }.map(&:label)
      labels << "Fit" if fit_total.to_i.positive?

      {
        total: total,
        max_total: max_total,
        pillar_labels: labels,
        summary_text: labels.join(" + ").presence
      }
    end

    def build_pillar(pillar)
      groups = Array(pillar[:groups]).map { |group| build_group(group) }
      lines =
        if groups.any?
          groups.flat_map(&:lines)
        else
          pillar[:rules].map { |rule| build_line(rule) }
        end

      Pillar.new(
        key: pillar[:key],
        label: pillar[:label],
        blurb: pillar[:blurb],
        lines: lines,
        groups: groups.presence,
        total: lines.select(&:awarded?).sum(&:points),
        max_total: lines.sum(&:points),
        unchecked_count: lines.count { |line| line.status == :unchecked },
        color: PILLAR_COLORS[pillar[:key]]
      )
    end

    def build_group(group)
      lines = group[:rules].map { |rule| build_line(rule) }
      Group.new(
        key: group[:key],
        label: group[:label],
        lines: lines,
        total: lines.select(&:awarded?).sum(&:points),
        max_total: group[:rules].sum { |rule| rule[:points] },
        unchecked_count: lines.count { |line| line.status == :unchecked }
      )
    end

    def build_line(rule)
      result = evaluate(rule[:key], rule[:label], rule[:points])
      status, detail, label = result
      points = result.length > 3 ? result[3] : rule[:points]
      Line.new(
        key: rule[:key],
        label: label,
        points: points,
        status: status,
        detail: detail
      )
    end

    def build_fit_line(rule)
      points, detail = evaluate_fit(rule[:key], rule[:points])
      Line.new(
        key: rule[:key],
        label: rule[:label],
        points: points,
        status: points.positive? ? :gap : :ok,
        detail: detail
      )
    end

    def evaluate(key, default_label, default_points = 0)
      case key
      when :no_website then no_website(default_label, default_points)
      when :weak_brand then weak_brand(default_label, default_points)
      when :hosting_maintenance then hosting_maintenance(default_label, default_points)
      when :no_places then no_places(default_label, default_points)
      when :weak_reviews then weak_reviews(default_label, default_points)
      when :no_facebook then social_check(:facebook, default_label)
      when :no_linkedin then social_check(:linkedin, default_label)
      else [:ok, nil, default_label, default_points]
      end
    end

    def evaluate_fit(key, max_points = 0)
      case key
      when :contact_phone then contact_phone_fit(max_points)
      when :contact_email then contact_email_fit(max_points)
      when :new_business then new_business_fit(max_points)
      else [0, nil]
      end
    end

    def contact_outreach_points
      return CONTACT_OUTREACH_POINTS if @business.phone.present? || @business.email.present?

      0
    end

    def contact_phone_fit(max_points)
      phone = @business.phone.to_s.strip
      if phone.present?
        [max_points, phone]
      else
        [0, "No phone on file — use Check search or Advanced Place Data"]
      end
    end

    def contact_email_fit(max_points)
      email = @business.email.to_s.strip
      if email.present?
        [max_points, email]
      else
        [0, "No email on file — use Check search or enrichment"]
      end
    end

    def places_status
      value = @business.places_check_status.to_s
      return STATUS_FOUND if value.blank? && @business.google_place_id.present?

      value.presence || STATUS_UNCHECKED
    end

    def website_status
      value = @business.website_check_status.to_s
      return STATUS_MISSING if value == STATUS_MISSING
      return STATUS_FOUND if value == STATUS_FOUND

      value.presence || STATUS_UNCHECKED
    end

    def brand_status
      value = @business.brand_check_status.to_s
      return STATUS_MISSING if value == STATUS_MISSING
      return STATUS_FOUND if value == STATUS_FOUND

      value.presence || STATUS_UNCHECKED
    end

    def weak_brand(default_label, max_points)
      case brand_status
      when STATUS_UNCHECKED
        [:unchecked, "Qualify logo / brand", default_label, 0]
      when STATUS_MISSING
        [:gap, "Sell logo / brand refresh", "Logo / brand refresh opportunity", foundation_refresh_points(max_points)]
      else
        [:ok, "NA — not a brand refresh sell", default_label, 0]
      end
    end

    def no_places(default_label, max_points)
      case places_status
      when STATUS_UNCHECKED
        [:unchecked, "Run Google Places check", default_label]
      when STATUS_MISSING
        [:gap, "No match — sell Google presence / ReviewBox setup", "No Google Places match", max_points]
      else
        [:ok, nil, default_label, 0]
      end
    end

    def no_website(default_label, max_points)
      case website_status
      when STATUS_UNCHECKED
        detail =
          if @business.website.present?
            "Qualify website on file"
          else
            "Qualify website"
          end
        [:unchecked, detail, default_label, 0]
      when STATUS_MISSING
        if @business.website.present?
          [:gap, "Sell website refresh / redesign", default_label, foundation_refresh_points(max_points)]
        else
          [:gap, "Sell website / landing page", default_label, max_points]
        end
      else
        if @business.website.present?
          [:ok, "NA — website on file (not a new-site sell)", default_label, 0]
        else
          [:ok, "NA — no website sell opportunity", default_label, 0]
        end
      end
    end

    def hosting_status
      value = @business.hosting_check_status.to_s
      return STATUS_MISSING if value == STATUS_MISSING
      return STATUS_FOUND if value == STATUS_FOUND

      value.presence || STATUS_UNCHECKED
    end

    def hosting_maintenance(default_label, max_points)
      if @business.website.blank?
        [:ok, "NA — bundle with new website package", default_label, 0]
      elsif website_status == STATUS_MISSING
        [:ok, "NA — covered by website refresh sell", default_label, 0]
      else
        case hosting_status
        when STATUS_UNCHECKED
          [:unchecked, "Qualify hosting & maintenance", default_label, 0]
        when STATUS_MISSING
          [:gap, "Sell hosting & maintenance service package", default_label, max_points]
        else
          [:ok, "NA — not a hosting & maintenance sell", default_label, 0]
        end
      end
    end

    def foundation_refresh_points(max_points)
      (max_points * FOUNDATION_REFRESH_RATIO).round
    end

    def weak_reviews(default_label, max_points)
      case places_status
      when STATUS_UNCHECKED
        [:unchecked, "Check Google Places for reviews", default_label, 0]
      when STATUS_MISSING
        [:unchecked, "Match Google Places first — required for ReviewBox", default_label, 0]
      else
        evaluate_review_count(default_label)
      end
    end

    def evaluate_review_count(default_label)
      count = @business.google_rating_count.to_i
      gap_points = reviews_gap_points(count)

      if gap_points.zero?
        return [:ok, nil, default_label, 0]
      end

      [:gap, reviews_gap_detail(count), default_label, gap_points]
    end

    def reviews_gap_points(count)
      return REVIEWS_FEW_POINTS if count < REVIEWS_FEW_THRESHOLD
      return REVIEWS_LOW_POINTS if count < REVIEWS_LOW_THRESHOLD
      return REVIEWS_MID_POINTS if count < REVIEWS_MID_THRESHOLD

      0
    end

    def reviews_gap_detail(count)
      if count.zero?
        "No Google reviews — sell review generation"
      elsif count < REVIEWS_FEW_THRESHOLD
        "#{count} review#{'s' unless count == 1} — under #{REVIEWS_FEW_THRESHOLD} reviews"
      elsif count < REVIEWS_LOW_THRESHOLD
        "#{count} reviews — under #{REVIEWS_LOW_THRESHOLD} reviews"
      else
        "#{count} reviews — under #{REVIEWS_MID_THRESHOLD} reviews"
      end
    end

    def social_check(network, default_label)
      status_method = "#{network}_check_status"
      url_method = "#{network}_url"
      status = @business.public_send(status_method).to_s
      url = @business.public_send(url_method)

      status = STATUS_FOUND if status.blank? && url.present?
      status = STATUS_UNCHECKED if status.blank?

      case status
      when STATUS_UNCHECKED
        [:unchecked, "Go check #{network.to_s.humanize}", default_label]
      when STATUS_MISSING
        [:gap, "Sell #{network.to_s.humanize} / social presence", "No #{network.to_s.humanize} page"]
      else
        [:ok, nil, default_label]
      end
    end

    def new_business_fit(max_points)
      captured_at = @business.created_at
      return [0, "No capture date on file"] if captured_at.blank?

      age = Time.current - captured_at
      captured_label = I18n.l(captured_at.to_date, format: :long)
      detail = "Captured #{captured_label}"

      if age <= NEW_BUSINESS_FRESH_WINDOW
        [max_points, detail]
      elsif age <= NEW_BUSINESS_WINDOW
        [NEW_BUSINESS_MID_POINTS, "#{detail} · #{NEW_BUSINESS_MID_POINTS} after 2 weeks"]
      else
        [0, "#{detail} · outside 30-day window"]
      end
    end
  end
end
