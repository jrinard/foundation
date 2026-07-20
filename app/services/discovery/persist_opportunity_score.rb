# frozen_string_literal: true

module Discovery
  # Persists live OpportunityScorePreview onto discovery_businesses.
  class PersistOpportunityScore
    Result = Struct.new(:preview, :business, keyword_init: true)

    def self.call(discovery_business:)
      new(discovery_business: discovery_business).call
    end

    def initialize(discovery_business:)
      @business = discovery_business
    end

    def call
      preview = OpportunityScorePreview.call(discovery_business: @business)

      @business.update!(
        score: preview[:total],
        score_breakdown: serialize_breakdown(preview),
        score_summary: serialize_summary(preview),
        scored_at: Time.current
      )

      Result.new(preview: preview, business: @business)
    end

    private

    def serialize_breakdown(preview)
      {
        pillars: preview[:pillars].map { |pillar| serialize_pillar(pillar) },
        fit_lines: preview[:fit_lines].map { |line| serialize_line(line) },
        fit_total: preview[:fit_total],
        fit_max: preview[:fit_max],
        package_total: preview[:package_total],
        package_max: preview[:package_max],
        total: preview[:total],
        max_total: preview[:max_total],
        unchecked_total: preview[:unchecked_total],
        analyzed_count: preview[:analyzed_count],
        donut_segments: preview[:donut_segments]
      }
    end

    def serialize_pillar(pillar)
      {
        key: pillar.key.to_s,
        label: pillar.label,
        total: pillar.total,
        max_total: pillar.max_total,
        unchecked_count: pillar.unchecked_count,
        lines: pillar.lines.map { |line| serialize_line(line) }
      }
    end

    def serialize_line(line)
      {
        key: line.key.to_s,
        label: line.label,
        points: line.points,
        status: line.status.to_s,
        detail: line.detail
      }
    end

    def serialize_summary(preview)
      bullets = preview[:pillars].flat_map do |pillar|
        pillar.lines.select { |line| line.status == :gap }.map do |line|
          {
            pillar: pillar.key.to_s,
            pillar_label: pillar.label,
            label: line.label,
            points: line.points,
            detail: line.detail
          }
        end
      end

      {
        opportunity_summary: preview[:opportunity_summary],
        need_bullets: bullets
      }
    end
  end
end
