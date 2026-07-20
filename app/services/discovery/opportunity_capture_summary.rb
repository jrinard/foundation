# frozen_string_literal: true

module Discovery
  # Plain-language package conclusions from live score preview gaps.
  class OpportunityCaptureSummary
    def self.call(discovery_business:, score_preview: nil)
      new(discovery_business: discovery_business, score_preview: score_preview).call
    end

    def initialize(discovery_business:, score_preview: nil)
      @business = discovery_business
      @preview = score_preview || OpportunityScorePreview.call(discovery_business: discovery_business)
    end

    def call
      lines = indexed_lines
      bullets = []
      skip_social = false

      needs_website = gap?(lines, :no_website) && @business.website.blank?
      brand_refresh = gap?(lines, :weak_brand) && @business.website.present?
      needs_brand = gap?(lines, :weak_brand) && !brand_refresh
      needs_places = gap?(lines, :no_places)
      needs_reviews = gap?(lines, :weak_reviews)
      hosting_sell = gap?(lines, :hosting_maintenance)

      if needs_website && (needs_brand || brand_refresh)
        bullets << "Lead with a website + branding package and ReviewBox follow-through."
      elsif needs_website
        bullets << "Needs a new website / landing page — pair with ReviewBox when Places match."
      elsif brand_refresh && hosting_sell
        bullets << "Brand needs refresh; site is on file — add hosting & maintenance as the service package."
      elsif brand_refresh
        bullets << "Brand needs refresh — they already have a web presence worth upgrading."
      elsif needs_brand
        bullets << "Needs logo / brand work before or with a site build."
      elsif hosting_sell
        bullets << "Site on file — lead with hosting & maintenance rather than a full rebuild."
      end

      if needs_places && needs_reviews
        bullets << "Reputation growth priority: not on Google Places yet and weak reviews (ReviewBox)."
      elsif needs_places
        bullets << "Not on Google Places — lead with presence setup and ReviewBox."
      elsif needs_reviews
        bullets << "Matched on Google but reviews are thin — ReviewBox / reputation growth."
      end

      social_pillar = @preview[:pillars].find { |pillar| pillar.key == :social }
      social_has_gap = social_pillar&.lines&.any? { |line| line.status == :gap }
      social_unchecked = social_pillar&.unchecked_count.to_i.positive?

      if !social_has_gap || social_unchecked
        skip_social = true
        bullets << "Social & listings can wait — focus Foundation and Reputation first."
      end

      new_business = (@preview[:fit_lines] || []).find { |line| line.key == :new_business }
      if new_business&.points.to_i.zero? && @business.website.present?
        bullets << "Captured a while ago — they may already have systems in place; confirm scope before over-selling."
      end

      if bullets.empty?
        if @preview[:unchecked_total].to_i.positive?
          bullets << "Finish score card checks to generate a package recommendation."
        else
          bullets << "No major gaps flagged — lower urgency or already well covered online."
        end
      end

      {
        headline: build_headline(needs_website:, needs_places:, needs_reviews:, brand_refresh:, hosting_sell:),
        bullets: bullets.uniq,
        skip_social: skip_social
      }
    end

    private

    def indexed_lines
      @preview[:pillars].each_with_object({}) do |pillar, memo|
        pillar_lines = pillar.groups.present? ? pillar.groups.flat_map(&:lines) : pillar.lines
        pillar_lines.each { |line| memo[line.key] = line }
      end
    end

    def gap?(lines, key)
      lines[key]&.status == :gap
    end

    def build_headline(needs_website:, needs_places:, needs_reviews:, brand_refresh:, hosting_sell:)
      if needs_website && needs_places
        "Website + branding package with ReviewBox — skip social for now."
      elsif needs_places && needs_reviews
        "Reputation growth — Google Places + ReviewBox."
      elsif brand_refresh && hosting_sell
        "Refresh brand; sell hosting & maintenance on the site they already have."
      elsif brand_refresh
        "Brand refresh opportunity — established presence on file."
      elsif needs_website
        "New website / landing page opportunity."
      elsif hosting_sell
        "Hosting & maintenance service package."
      elsif needs_reviews
        "ReviewBox / reputation growth."
      else
        "Package summary"
      end
    end
  end
end
