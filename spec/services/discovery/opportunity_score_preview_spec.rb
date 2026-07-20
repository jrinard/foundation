# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::OpportunityScorePreview do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  def preview_for(attrs = {})
    business = create(:discovery_business, organization: organization, **attrs)
    described_class.call(discovery_business: business)
  end

  def website_line(preview)
    website_pillar(preview).lines.find { |l| l.key == :no_website }
  end

  def brand_line(preview)
    website_pillar(preview).lines.find { |l| l.key == :weak_brand }
  end

  def hosting_line(preview)
    website_pillar(preview).lines.find { |l| l.key == :hosting_maintenance }
  end

  def website_pillar(preview)
    preview[:pillars].find { |p| p.key == :website }
  end

  def new_business_line(preview)
    preview[:fit_lines].find { |l| l.key == :new_business }
  end

  def places_line(preview)
    reputation_pillar(preview).lines.find { |l| l.key == :no_places }
  end

  def reviews_line(preview)
    reputation_pillar(preview).lines.find { |l| l.key == :weak_reviews }
  end

  def reputation_pillar(preview)
    preview[:pillars].find { |p| p.key == :reputation }
  end

  it "scores full website gap when marked missing with no URL" do
    line = website_line(preview_for(website_check_status: DiscoveryBusiness::CHECK_MISSING))

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(50)
  end

  it "scores website refresh at half points when a URL is on file and sell is toggled" do
    line = website_line(
      preview_for(
        website: "https://example.com",
        website_check_status: DiscoveryBusiness::CHECK_MISSING
      )
    )

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(25)
    expect(line.detail).to include("refresh")
  end

  it "leaves website unchecked when a URL is on file until manually qualified" do
    line = website_line(preview_for(website: "https://example.com"))

    expect(line.status).to eq(:unchecked)
    expect(line.points).to eq(0)
  end

  it "treats a manually qualified website on file as NA" do
    line = website_line(
      preview_for(
        website: "https://example.com",
        website_check_status: DiscoveryBusiness::CHECK_FOUND
      )
    )

    expect(line.status).to eq(:ok)
    expect(line.points).to eq(0)
    expect(line.detail).to include("NA")
  end

  it "leaves website unchecked when neither places nor website check ran" do
    line = website_line(preview_for)

    expect(line.status).to eq(:unchecked)
  end

  it "leaves website unchecked when places are checked but website is not qualified" do
    line = website_line(
      preview_for(
        places_check_status: DiscoveryBusiness::CHECK_MISSING,
        google_place_id: nil
      )
    )

    expect(line.status).to eq(:unchecked)
    expect(line.points).to eq(0)
  end

  it "scores brand gap at half points when sell is toggled on" do
    line = brand_line(preview_for(brand_check_status: DiscoveryBusiness::CHECK_MISSING))

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(25)
  end

  it "leaves brand unchecked until reviewed" do
    line = brand_line(preview_for)

    expect(line.status).to eq(:unchecked)
  end

  it "shows a checked state for ok lines and 0 for unchecked" do
    unchecked = website_line(preview_for)
    expect(unchecked.display_points_label).to eq("0")
    expect(unchecked.checked?).to be(false)

    ok = website_line(
      preview_for(
        website: "https://example.com",
        website_check_status: DiscoveryBusiness::CHECK_FOUND
      )
    )
    expect(ok.status).to eq(:ok)
    expect(ok.checked?).to be(true)

    gap = website_line(preview_for(website_check_status: DiscoveryBusiness::CHECK_MISSING))
    expect(gap.display_points_label).to eq("+50")
    expect(gap.checked?).to be(false)
  end

  it "includes a Foundation group under the website pillar" do
    preview = preview_for
    pillar = website_pillar(preview)

    expect(pillar.groups.size).to eq(1)
    expect(pillar.groups.first.label).to eq("Identity and Landing")
    expect(pillar.groups.first.lines.map(&:key)).to eq([:weak_brand, :no_website, :hosting_maintenance])
  end

  it "leaves hosting unchecked until Sell is toggled when a website is on file" do
    line = hosting_line(preview_for(website: "https://example.com"))

    expect(line.status).to eq(:unchecked)
    expect(line.points).to eq(0)
    expect(line.detail).to include("Qualify hosting")
  end

  it "scores hosting and maintenance when Sell is toggled on" do
    line = hosting_line(
      preview_for(
        website: "https://example.com",
        hosting_check_status: DiscoveryBusiness::CHECK_MISSING
      )
    )

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(25)
    expect(line.detail).to include("hosting")
  end

  it "marks hosting and maintenance NA when Sell is toggled off" do
    line = hosting_line(
      preview_for(
        website: "https://example.com",
        hosting_check_status: DiscoveryBusiness::CHECK_FOUND
      )
    )

    expect(line.status).to eq(:ok)
    expect(line.points).to eq(0)
    expect(line.detail).to include("NA")
  end

  it "marks hosting and maintenance NA when no website is on file" do
    line = hosting_line(preview_for)

    expect(line.status).to eq(:ok)
    expect(line.points).to eq(0)
    expect(line.detail).to include("NA")
  end

  it "marks hosting and maintenance NA when website refresh is the sell" do
    line = hosting_line(
      preview_for(
        website: "https://example.com",
        website_check_status: DiscoveryBusiness::CHECK_MISSING
      )
    )

    expect(line.status).to eq(:ok)
    expect(line.points).to eq(0)
    expect(line.detail).to include("refresh")
  end

  it "includes a capture summary on the preview payload" do
    preview = preview_for(website_check_status: DiscoveryBusiness::CHECK_MISSING)

    expect(preview[:capture_summary]).to include(:headline, :bullets, :skip_social)
    expect(preview[:capture_summary][:headline]).to be_present
    expect(preview[:capture_summary][:bullets]).to be_an(Array)
  end

  it "builds donut nubs that light individually before the pillar arc is fully analyzed" do
    preview = preview_for(
      brand_check_status: DiscoveryBusiness::CHECK_MISSING,
      website_check_status: DiscoveryBusiness::CHECK_UNCHECKED
    )
    foundation = preview[:donut_segments].find { |segment| segment[:key] == :website }

    expect(foundation[:parts].size).to eq(3)
    expect(foundation[:parts].count { |part| part[:accounted] }).to eq(2)
    expect(foundation[:analyzed]).to be(false)
    expect(preview[:donut_progress][:total]).to eq(7)
    expect(preview[:donut_progress][:accounted]).to eq(2)
  end

  it "marks a donut pillar analyzed only when all its parts are accounted for" do
    preview = preview_for(
      brand_check_status: DiscoveryBusiness::CHECK_MISSING,
      website_check_status: DiscoveryBusiness::CHECK_FOUND,
      hosting_check_status: DiscoveryBusiness::CHECK_MISSING,
      website: "https://example.com",
      places_check_status: DiscoveryBusiness::CHECK_FOUND,
      google_place_id: "abc123",
      google_rating_count: 50
    )
    foundation = preview[:donut_segments].find { |segment| segment[:key] == :website }

    expect(foundation[:parts].all? { |part| part[:accounted] }).to be(true)
    expect(foundation[:analyzed]).to be(true)
  end

  it "awards 100 new-business fit points inside 2 weeks and shows capture date" do
    travel_to Time.zone.parse("2026-07-17 12:00:00") do
      line = new_business_line(preview_for(created_at: 10.days.ago))

      expect(line.status).to eq(:gap)
      expect(line.points).to eq(100)
      expect(line.detail).to include("Captured")
      expect(line.detail).to include("July")
      expect(line.detail).not_to include("after 2 weeks")
    end
  end

  it "awards 50 new-business fit points after 2 weeks and inside 30 days" do
    travel_to Time.zone.parse("2026-07-17 12:00:00") do
      line = new_business_line(preview_for(created_at: 20.days.ago))

      expect(line.status).to eq(:gap)
      expect(line.points).to eq(50)
      expect(line.detail).to include("50 after 2 weeks")
    end
  end

  it "drops new-business fit points after 30 days" do
    travel_to Time.zone.parse("2026-07-17 12:00:00") do
      line = new_business_line(preview_for(created_at: 31.days.ago))

      expect(line.status).to eq(:ok)
      expect(line.points).to eq(0)
      expect(line.detail).to include("outside 30-day window")
    end
  end

  it "scores places gap at 25 when no Google match" do
    line = places_line(preview_for(places_check_status: DiscoveryBusiness::CHECK_MISSING))

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(25)
  end

  it "awards 50 review gap points at zero reviews when places are matched" do
    line = reviews_line(
      preview_for(
        places_check_status: DiscoveryBusiness::CHECK_FOUND,
        google_place_id: "abc123",
        google_rating: nil,
        google_rating_count: 0
      )
    )

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(50)
    expect(line.detail).to include("No Google reviews")
  end

  it "awards 50 review gap points when under 3 reviews" do
    line = reviews_line(
      preview_for(
        places_check_status: DiscoveryBusiness::CHECK_FOUND,
        google_place_id: "abc123",
        google_rating: 4.5,
        google_rating_count: 2
      )
    )

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(50)
  end

  it "awards 25 review gap points when under 10 reviews" do
    line = reviews_line(
      preview_for(
        places_check_status: DiscoveryBusiness::CHECK_FOUND,
        google_place_id: "abc123",
        google_rating: 4.5,
        google_rating_count: 5
      )
    )

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(25)
    expect(line.detail).to include("under 10")
  end

  it "awards 15 review gap points when under 50 reviews" do
    line = reviews_line(
      preview_for(
        places_check_status: DiscoveryBusiness::CHECK_FOUND,
        google_place_id: "abc123",
        google_rating: 4.2,
        google_rating_count: 25
      )
    )

    expect(line.status).to eq(:gap)
    expect(line.points).to eq(15)
  end

  it "clears review gap when count reaches 50" do
    line = reviews_line(
      preview_for(
        places_check_status: DiscoveryBusiness::CHECK_FOUND,
        google_place_id: "abc123",
        google_rating: 4.2,
        google_rating_count: 50
      )
    )

    expect(line.status).to eq(:ok)
    expect(line.points).to eq(0)
  end

  it "leaves reviews unchecked until places are matched" do
    line = reviews_line(preview_for(places_check_status: DiscoveryBusiness::CHECK_MISSING))

    expect(line.status).to eq(:unchecked)
    expect(line.points).to eq(0)
  end
end
