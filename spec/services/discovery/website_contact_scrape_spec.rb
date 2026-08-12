# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::WebsiteContactScrape do
  let(:base_url) { "https://acme-detailing.com" }

  def stub_fetch_html(paths_with_html)
    allow_any_instance_of(described_class).to receive(:fetch_html) do |_instance, _base, path|
      paths_with_html[path]
    end
  end

  def stub_fetch_body(urls_with_body)
    allow_any_instance_of(described_class).to receive(:fetch_body) do |_instance, url, **_kwargs|
      urls_with_body[url]
    end
  end

  it "extracts email and phone from contact page content" do
    html = <<~HTML
      <html><body>
        <a href="mailto:Hello@Acme-Detailing.com">Email us</a>
        <p>Call (360) 555-1212 today</p>
      </body></html>
    HTML

    stub_fetch_html("" => nil, "/contact" => html)
    stub_fetch_body({})

    result = described_class.call(url: "acme-detailing.com")

    expect(result.ok).to be(true)
    expect(result.email).to eq("hello@acme-detailing.com")
    expect(result.phone).to eq("(360) 555-1212")
    expect(result.pages_checked).to include("/contact")
  end

  it "filters junk emails" do
    html = <<~HTML
      <html><body>
        <a href="mailto:noreply@wixpress.com">Hidden</a>
        <a href="mailto:info@acme-detailing.com">Info</a>
      </body></html>
    HTML

    stub_fetch_html("" => html)
    stub_fetch_body({})

    result = described_class.call(url: base_url)

    expect(result.email).to eq("info@acme-detailing.com")
  end

  it "returns a helpful message when nothing is found" do
    empty_html = "<html><body></body></html>"
    stub_fetch_html(
      "" => empty_html,
      "/contact" => empty_html,
      "/contact-us" => empty_html,
      "/about" => empty_html,
      "/about-us" => empty_html
    )
    stub_fetch_body({})

    result = described_class.call(url: "https://empty.example")

    expect(result.ok).to be(true)
    expect(result.phone).to be_nil
    expect(result.email).to be_nil
    expect(result.message).to include("No phone, email, or social")
  end

  it "uses sitemap contact pages before fallback paths" do
    sitemap = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>https://acme-detailing.com/get-in-touch</loc></url>
        <url><loc>https://acme-detailing.com/services</loc></url>
      </urlset>
    XML

    contact_html = <<~HTML
      <html><body>
        <a href="mailto:hello@acme-detailing.com">Email</a>
      </body></html>
    HTML

    stub_fetch_body(
      "#{base_url}/robots.txt" => nil,
      "#{base_url}/sitemap.xml" => sitemap
    )
    stub_fetch_html(
      "" => nil,
      "/get-in-touch" => contact_html,
      "/contact" => nil,
      "/contact-us" => nil,
      "/about" => nil,
      "/about-us" => nil
    )

    result = described_class.call(url: base_url)

    expect(result.ok).to be(true)
    expect(result.email).to eq("hello@acme-detailing.com")
    expect(result.pages_checked).to include("/get-in-touch")
    expect(result.pages_checked).not_to include("/services")
  end

  it "reads sitemap URL from robots.txt" do
    robots = "User-agent: *\nSitemap: https://acme-detailing.com/custom-sitemap.xml\n"
    sitemap = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        <url><loc>https://acme-detailing.com/contact-us</loc></url>
      </urlset>
    XML
    contact_html = <<~HTML
      <html><body><a href="mailto:info@acme-detailing.com">Info</a></body></html>
    HTML

    stub_fetch_body(
      "#{base_url}/robots.txt" => robots,
      "https://acme-detailing.com/custom-sitemap.xml" => sitemap
    )
    stub_fetch_html(
      "" => nil,
      "/contact-us" => contact_html,
      "/contact" => nil,
      "/about" => nil,
      "/about-us" => nil
    )

    result = described_class.call(url: base_url)

    expect(result.email).to eq("info@acme-detailing.com")
    expect(result.pages_checked).to include("/contact-us")
  end

  it "extracts facebook and linkedin links from page anchors" do
    html = <<~HTML
      <html><body>
        <a href="https://www.facebook.com/AcmeDetailing">Facebook</a>
        <a href="https://linkedin.com/company/acme-detailing">LinkedIn</a>
        <a href="https://www.instagram.com/acme_detailing/">Instagram</a>
      </body></html>
    HTML

    stub_fetch_html("" => html)
    stub_fetch_body({})

    result = described_class.call(url: base_url)

    expect(result.facebook_url).to eq("https://www.facebook.com/AcmeDetailing")
    expect(result.linkedin_url).to eq("https://www.linkedin.com/company/acme-detailing")
    expect(result.instagram_url).to eq("https://www.instagram.com/acme_detailing")
  end

  it "preserves facebook profile.php query params" do
    html = <<~HTML
      <html><body>
        <a href="https://www.facebook.com/profile.php?id=61570904904131">Facebook</a>
      </body></html>
    HTML

    stub_fetch_html("" => html)
    stub_fetch_body({})

    result = described_class.call(url: base_url)

    expect(result.facebook_url).to eq("https://www.facebook.com/profile.php?id=61570904904131")
  end

  it "prefers linkedin company pages over personal profiles" do
    html = <<~HTML
      <html><body>
        <a href="https://www.linkedin.com/in/owner-name">Owner</a>
        <a href="https://www.linkedin.com/company/acme-detailing">Company</a>
      </body></html>
    HTML

    stub_fetch_html("" => html)
    stub_fetch_body({})

    result = described_class.call(url: base_url)

    expect(result.linkedin_url).to eq("https://www.linkedin.com/company/acme-detailing")
  end

  it "ignores facebook share and linkedin share links" do
    html = <<~HTML
      <html><body>
        <a href="https://www.facebook.com/sharer/sharer.php?u=example">Share</a>
        <a href="https://www.linkedin.com/shareArticle?url=example">Share</a>
        <a href="https://www.instagram.com/p/ABC123/">Post</a>
      </body></html>
    HTML

    stub_fetch_html("" => html)
    stub_fetch_body({})

    result = described_class.call(url: base_url)

    expect(result.facebook_url).to be_nil
    expect(result.linkedin_url).to be_nil
    expect(result.instagram_url).to be_nil
  end
end
