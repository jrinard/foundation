# frozen_string_literal: true

require "net/http"
require "uri"
require "nokogiri"

module Discovery
  # Lightweight homepage + sitemap-guided contact-page scrape for public phone/email.
  class WebsiteContactScrape
    EMAIL_PATTERN = /
      [a-zA-Z0-9._%+\-]+@
      [a-zA-Z0-9.\-]+\.
      [a-zA-Z]{2,}
    /x

    PHONE_PATTERN = /
      (?:
        \+1[\s.\-]?
      )?
      \(?\d{3}\)?[\s.\-]?\d{3}[\s.\-]?\d{4}
    /x

    FALLBACK_CONTACT_PATHS = ["/contact", "/contact-us", "/about", "/about-us"].freeze
    MAX_PAGES = 6
    MAX_SITEMAP_CONTACT_PATHS = 3

    CONTACT_PATH_KEYWORDS = /
      contact |
      about |
      reach |
      location |
      get-in-touch |
      connect |
      office
    /ix

    CONTACT_PATH_SCORES = [
      [/contact/i, 0],
      [/get-in-touch|reach-us|connect/i, 1],
      [/about/i, 2],
      [/location/i, 3],
      [/office/i, 4]
    ].freeze

    JUNK_EMAIL_FRAGMENTS = %w[
      noreply no-reply donotreply do-not-reply
      sentry wixpress wordpress example.com
      .png .jpg .jpeg .gif .webp .svg
      users.noreply github facebook instagram
    ].freeze

    PREFERRED_EMAIL_LOCAL_PARTS = %w[info contact hello office sales support].freeze

    Result = Struct.new(
      :ok, :message, :website, :pages_checked, :phone, :email,
      :facebook_url, :linkedin_url, :instagram_url,
      keyword_init: true
    )

    def self.call(url:)
      new(url).call
    end

    def initialize(url)
      @url = url.to_s.strip
    end

    def call
      website = normalize_url(@url)
      return failure("Missing website URL.") if website.blank?

      pages_checked = []
      emails = []
      phones = []
      facebook_urls = []
      linkedin_urls = []
      instagram_urls = []

      build_scrape_paths(website).each do |path|
        html = fetch_html(website, path)
        next if html.blank?

        pages_checked << path.presence || "/"
        text = extract_text(html)
        emails.concat extract_emails(text, html)
        phones.concat extract_phones(text)
        social = extract_social_links(html)
        facebook_urls.concat social[:facebook]
        linkedin_urls.concat social[:linkedin]
        instagram_urls.concat social[:instagram]
      end

      email = pick_email(emails)
      phone = pick_phone(phones)
      facebook_url = pick_facebook_url(facebook_urls)
      linkedin_url = pick_linkedin_url(linkedin_urls)
      instagram_url = pick_instagram_url(instagram_urls)

      if email.blank? && phone.blank? && facebook_url.blank? && linkedin_url.blank? && instagram_url.blank?
        return Result.new(
          ok: true,
          message: "No phone, email, or social links found on the site pages we checked.",
          website: website,
          pages_checked: pages_checked,
          phone: nil,
          email: nil,
          facebook_url: nil,
          linkedin_url: nil,
          instagram_url: nil
        )
      end

      Result.new(
        ok: true,
        message: nil,
        website: website,
        pages_checked: pages_checked,
        phone: phone,
        email: email,
        facebook_url: facebook_url,
        linkedin_url: linkedin_url,
        instagram_url: instagram_url
      )
    rescue StandardError => e
      failure("Website scrape failed: #{e.message}")
    end

    private

    def build_scrape_paths(website)
      paths = [""]
      paths.concat(discover_sitemap_contact_paths(website))

      FALLBACK_CONTACT_PATHS.each do |path|
        break if paths.length >= MAX_PAGES

        paths << path unless paths.include?(path)
      end

      paths.first(MAX_PAGES)
    end

    def discover_sitemap_contact_paths(website)
      sitemap_urls = sitemap_urls_from_robots(website)
      if sitemap_urls.empty?
        sitemap_urls << URI.join("#{website}/", "sitemap.xml").to_s
      end

      loc_urls = []
      sitemap_urls.uniq.first(2).each do |sitemap_url|
        loc_urls.concat(parse_sitemap_locs(sitemap_url, website))
      end

      rank_contact_urls(loc_urls, website)
        .first(MAX_SITEMAP_CONTACT_PATHS)
        .filter_map { |url| path_from_url(url, website) }
        .reject { |path| path == "/" }
    end

    def sitemap_urls_from_robots(website)
      robots_url = URI.join("#{website}/", "robots.txt").to_s
      body = fetch_body(robots_url, accept: "text/plain,*/*")
      return [] if body.blank?

      body
        .each_line
        .filter_map do |line|
          match = line.match(/\ASitemap:\s*(.+)\z/i)
          match&.[](1)&.strip
        end
        .reject(&:blank?)
    end

    def parse_sitemap_locs(sitemap_url, website, depth: 0)
      return [] if depth > 1

      body = fetch_body(sitemap_url, accept: "application/xml,text/xml,*/*")
      return [] if body.blank?

      doc = Nokogiri::XML(body)
      doc.remove_namespaces!

      if doc.at("sitemapindex")
        child_urls = doc.css("sitemap loc").map { |node| node.text.to_s.strip }.reject(&:blank?)
        return child_urls.flat_map { |url| parse_sitemap_locs(url, website, depth: depth + 1) }
      end

      doc.css("url loc").map { |node| node.text.to_s.strip }.reject(&:blank?)
    rescue StandardError
      []
    end

    def rank_contact_urls(urls, website)
      base_host = URI.parse(website).host

      urls
        .select { |url| same_host?(url, base_host) }
        .select { |url| contact_like_path?(url) }
        .uniq
        .sort_by { |url| contact_path_rank(url) }
    rescue URI::InvalidURIError
      []
    end

    def same_host?(url, base_host)
      URI.parse(url).host.to_s.casecmp?(base_host.to_s)
    rescue URI::InvalidURIError
      false
    end

    def contact_like_path?(url)
      path = URI.parse(url).path.to_s
      CONTACT_PATH_KEYWORDS.match?(path)
    rescue URI::InvalidURIError
      false
    end

    def contact_path_rank(url)
      path = URI.parse(url).path.to_s.downcase
      matched = CONTACT_PATH_SCORES.find { |pattern, _score| path.match?(pattern) }
      matched ? matched.last : 99
    rescue URI::InvalidURIError
      99
    end

    def path_from_url(url, website)
      page_uri = URI.parse(url)
      base_uri = URI.parse(website)
      return unless page_uri.host.to_s.casecmp?(base_uri.host.to_s)

      path = page_uri.path.presence || "/"
      path
    rescue URI::InvalidURIError
      nil
    end

    def normalize_url(raw)
      value = raw.to_s.strip
      return if value.blank?

      value = "https://#{value}" unless value.match?(%r{\Ahttps?://}i)
      uri = URI.parse(value)
      return if uri.host.blank?

      uri.fragment = nil
      uri.to_s.sub(%r{/\z}, "")
    rescue URI::InvalidURIError
      nil
    end

    def fetch_html(base_url, path)
      target =
        if path.blank?
          base_url
        else
          URI.join("#{base_url}/", path.delete_prefix("/")).to_s
        end

      fetch_body(target, accept: "text/html,application/xhtml+xml")
    end

    def fetch_body(url, accept: "text/html,application/xhtml+xml")
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 8
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "FoundationDiscovery/1.0 (+contact-enrichment)"
      request["Accept"] = accept

      response = http.request(request)
      return unless response.is_a?(Net::HTTPSuccess)

      body = response.body.to_s
      return if body.blank?

      body.force_encoding("UTF-8")
      body.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    rescue StandardError
      nil
    end

    def extract_text(html)
      doc = Nokogiri::HTML(html)
      doc.css("script, style, noscript").remove
      doc.text.to_s.gsub(/\s+/, " ")
    end

    def extract_emails(text, html)
      doc = Nokogiri::HTML(html)
      mailtos = doc.css('a[href^="mailto:"]').map { |node| node["href"].to_s.sub(/\Amailto:/i, "").split("?").first }
      found = mailtos + text.to_s.scan(EMAIL_PATTERN)
      found.map { |value| clean_email(value) }.compact.uniq
    end

    def extract_phones(text)
      text.to_s.scan(PHONE_PATTERN).map { |value| format_phone(value) }.compact.uniq
    end

    FACEBOOK_HOST_PATTERN = /(?:^|\.)((?:facebook|fb)\.com)\z/i
    LINKEDIN_HOST_PATTERN = /(?:^|\.)linkedin\.com\z/i
    INSTAGRAM_HOST_PATTERN = /(?:^|\.)instagram\.com\z/i

    FACEBOOK_REJECT_PATH = %r{
      /(?:sharer|share\.php|dialog|plugins|login|help|policies|privacy|l\.php|tr\.php|watch|marketplace|groups|events)
    }ix

    LINKEDIN_REJECT_PATH = %r{
      /(?:shareArticle|sharing|login|legal|jobs/search|signup)
    }ix

    INSTAGRAM_REJECT_PATH = %r{
      /(?:p|reel|reels|tv|stories|explore|accounts|about|legal|developer|direct|nametag|challenge|privacy|terms|web)
    }ix

    INSTAGRAM_RESERVED_SLUGS = %w[
      about explore reels stories direct accounts login signup help privacy terms web
    ].freeze

    def extract_social_links(html)
      doc = Nokogiri::HTML(html)
      hrefs = doc.css("a[href]").map { |node| node["href"].to_s.strip }.reject(&:blank?)
      hrefs.concat html.to_s.scan(%r{https?://[^\s"'<>]*(?:facebook|fb)\.com[^\s"'<>]*}i)
      hrefs.concat html.to_s.scan(%r{https?://[^\s"'<>]*linkedin\.com[^\s"'<>]*}i)
      hrefs.concat html.to_s.scan(%r{https?://[^\s"'<>]*instagram\.com[^\s"'<>]*}i)

      facebook = []
      linkedin = []
      instagram = []

      hrefs.each do |href|
        normalized_facebook = normalize_facebook_url(href)
        facebook << normalized_facebook if normalized_facebook

        normalized_linkedin = normalize_linkedin_url(href)
        linkedin << normalized_linkedin if normalized_linkedin

        normalized_instagram = normalize_instagram_url(href)
        instagram << normalized_instagram if normalized_instagram
      end

      { facebook: facebook.uniq, linkedin: linkedin.uniq, instagram: instagram.uniq }
    end

    def normalize_facebook_url(raw)
      url = normalize_external_url(raw)
      return if url.blank?

      uri = URI.parse(url)
      return unless uri.host.to_s.match?(FACEBOOK_HOST_PATTERN)
      return if uri.path.to_s.match?(FACEBOOK_REJECT_PATH)

      path = uri.path.to_s.strip
      return if path.blank? || path == "/"

      canonical_social_url(host: "www.facebook.com", path: path, query: uri.query)
    rescue URI::InvalidURIError
      nil
    end

    def normalize_linkedin_url(raw)
      url = normalize_external_url(raw)
      return if url.blank?

      uri = URI.parse(url)
      return unless uri.host.to_s.match?(LINKEDIN_HOST_PATTERN)
      return if uri.path.to_s.match?(LINKEDIN_REJECT_PATH)

      path = uri.path.to_s.strip
      return if path.blank? || path == "/"

      canonical_social_url(host: "www.linkedin.com", path: path, query: uri.query)
    rescue URI::InvalidURIError
      nil
    end

    def normalize_instagram_url(raw)
      url = normalize_external_url(raw)
      return if url.blank?

      uri = URI.parse(url)
      return unless uri.host.to_s.match?(INSTAGRAM_HOST_PATTERN)
      return if uri.path.to_s.match?(INSTAGRAM_REJECT_PATH)

      segments = uri.path.to_s.split("/").reject(&:blank?)
      return if segments.length != 1

      slug = segments.first.to_s
      return if slug.blank?
      return if INSTAGRAM_RESERVED_SLUGS.include?(slug.downcase)
      return unless slug.match?(/\A[A-Za-z0-9._]+\z/)

      canonical_social_url(host: "www.instagram.com", path: "/#{slug}")
    rescue URI::InvalidURIError
      nil
    end

    def canonical_social_url(host:, path:, query: nil)
      URI::HTTPS.build(host: host, path: path, query: query).to_s
    end

    def normalize_external_url(raw)
      value = raw.to_s.strip
      return if value.blank?
      return if value.start_with?("#", "javascript:", "mailto:", "tel:")

      value = "https://#{value}" unless value.match?(%r{\Ahttps?://}i)
      uri = URI.parse(value)
      return if uri.host.blank?

      uri.fragment = nil
      uri.to_s.sub(%r{/\z}, "")
    rescue URI::InvalidURIError
      nil
    end

    def pick_facebook_url(urls)
      return if urls.blank?

      urls.first
    end

    def pick_linkedin_url(urls)
      return if urls.blank?

      urls.min_by { |url| url.include?("/company/") ? 0 : 1 }
    end

    def pick_instagram_url(urls)
      return if urls.blank?

      urls.first
    end

    def clean_email(value)
      email = value.to_s.strip.downcase
      return if email.blank?
      return if JUNK_EMAIL_FRAGMENTS.any? { |junk| email.include?(junk) }

      email
    end

    def pick_email(emails)
      return if emails.blank?

      emails.min_by do |email|
        local = email.split("@").first.to_s
        rank = PREFERRED_EMAIL_LOCAL_PARTS.index(local)
        [rank ? 0 : 1, rank || 99, email.length]
      end
    end

    def pick_phone(phones)
      return if phones.blank?

      phones.first
    end

    def format_phone(value)
      digits = value.to_s.gsub(/\D/, "")
      digits = digits[1..] if digits.length == 11 && digits.start_with?("1")
      return if digits.length != 10

      "(#{digits[0, 3]}) #{digits[3, 3]}-#{digits[6, 4]}"
    end

    def failure(message)
      Result.new(
        ok: false,
        message: message,
        website: nil,
        pages_checked: [],
        phone: nil,
        email: nil,
        facebook_url: nil,
        linkedin_url: nil,
        instagram_url: nil
      )
    end
  end
end
