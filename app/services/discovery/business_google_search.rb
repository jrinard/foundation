# frozen_string_literal: true

require "cgi"

module Discovery
  # Builds a Google search URL from Discovery business identity fields.
  # Tuned for fringe / low-index SMBs: directory mirrors, owner cross-refs, UBI hits.
  class BusinessGoogleSearch
    CORP_AGENT_PATTERN = /\b(
      registered\s+agents? |
      ct\s+corporation |
      northwest\s+registered |
      national\s+registered |
      corporation\s+service |
      incorp\s+services |
      united\s+agent |
      csc\s+lawyers |
      resident\s+agents? |
      registered\s+agent\s+solutions |
      agent\s+service
    )\b/ix

    LEGAL_SUFFIX_PATTERN = /\b(
      LLC|L\.L\.C\.|PLLC|P\.L\.L\.C\.|
      INC|INCORPORTED|CORP|CORPORATION|
      LTD|LIMITED|CO|COMPANY|
      PC|P\.C\.|LP|LLP|PS
    )\.?/ix

    ZIP_PATTERN = /\b(\d{5})(?:-\d{4})?\b/

    DIRECTORY_SITES = %w[
      facebook.com
      yelp.com
      bbb.org
      yellowpages.com
      manta.com
      buildzoom.com
      mapquest.com
      bizapedia.com
      opencorporates.com
      chamberofcommerce.com
    ].freeze

    SOCIAL_SITES = %w[
      facebook.com
      linkedin.com
      instagram.com
      nextdoor.com
      alignable.com
    ].freeze

    REPUTATION_SITES = %w[
      google.com/maps
      g.page
      yelp.com
      bbb.org
      facebook.com
    ].freeze

    CONTACT_SIGNALS = %w[
      phone
      email
      contact
      cellphone
      mobile
      tel
      @gmail.com
      @yahoo.com
      @outlook.com
      call\ us
      contact\ us
    ].freeze

    OWNER_SIGNALS = %w[
      owner
      principal
      founder
      president
      manager
    ].freeze

    PILLAR_INTENTS = {
      website: :foundation,
      reputation: :reputation,
      social: :social
    }.freeze

    def self.call(discovery_business:, intent: :contact)
      new(discovery_business: discovery_business, intent: intent).url
    end

    def initialize(discovery_business:, intent: :contact)
      @business = discovery_business
      @intent = PILLAR_INTENTS.fetch(intent.to_sym, intent.to_sym)
    end

    def url
      "https://www.google.com/search?q=#{CGI.escape(query)}"
    end

    def query
      case @intent
      when :foundation then foundation_query
      when :reputation then reputation_query
      when :social then social_query
      else contact_query
      end
    end

    private

    attr_reader :business

    def foundation_query
      join_tokens(
        name_group,
        identity_group,
        location_group,
        vertical_hint,
        contact_signal_group,
        directory_site_group(DIRECTORY_SITES),
        ubi_group
      )
    end

    def reputation_query
      join_tokens(
        name_group,
        location_group,
        group("reviews", "rating", "google business", "google maps", "places"),
        directory_site_group(REPUTATION_SITES)
      )
    end

    def social_query
      join_tokens(
        name_group,
        location_group,
        group("facebook", "linkedin", "instagram", "social"),
        directory_site_group(SOCIAL_SITES)
      )
    end

    def contact_query
      foundation_query
    end

    def name_group
      legal = business.business_name.to_s.strip
      trade = trade_name
      core = core_name_tokens

      terms = []
      terms << quoted(legal) if legal.present?
      terms << quoted(trade) if trade.present? && !same_name?(trade, legal)
      terms << quoted(core) if core.present? && terms.none? { |term| same_name?(term, core) }

      group(terms)
    end

    def identity_group
      agent = useful_agent_name
      trade = trade_name

      if agent.present?
        terms = [quoted(agent), *OWNER_SIGNALS.map(&:dup)]
        terms << quoted("#{agent} #{trade}") if trade.present?
        terms << quoted("#{trade} #{agent}") if trade.present?
        group(terms.uniq)
      else
        group(*OWNER_SIGNALS, "doing business as", "DBA")
      end
    end

    def location_group
      terms = []
      city = business.display_city.to_s.strip
      terms << "#{city} WA" if city.present?
      terms << zip_code if zip_code.present?

      street = street_fragment
      terms << quoted(street) if street.present?

      compact = compact_address
      if compact.present? && compact != street
        terms << quoted(compact)
      end

      group(terms.uniq) if terms.any?
    end

    def vertical_hint
      vertical = business.vertical_classification.to_s.strip
      return quoted(vertical) if vertical.present?

      hint = trade_hint_from_name
      quoted(hint) if hint.present?
    end

    def contact_signal_group
      group(*CONTACT_SIGNALS)
    end

    def directory_site_group(sites)
      group(sites.map { |site| "site:#{site}" })
    end

    def ubi_group
      variants = ubi_variants
      return if variants.blank?

      group(*variants, "UBI", "Washington secretary of state")
    end

    def ubi_variants
      digits = business.display_ubi.to_s.gsub(/\D/, "")
      return [] if digits.blank?

      variants = [quoted(digits)]
      if digits.length == 9
        spaced = digits.gsub(/(\d{3})(\d{3})(\d{3})/, '\1 \2 \3')
        variants << quoted(spaced)
        variants << quoted("#{digits[0, 3]} #{digits[3, 3]}-#{digits[6, 3]}")
      end

      variants.uniq
    end

    def trade_name
      business.business_name.to_s
        .gsub(LEGAL_SUFFIX_PATTERN, " ")
        .gsub(/\s+/, " ")
        .strip
    end

    def core_name_tokens
      trade = trade_name
      return if trade.blank?

      words = trade.split(/\s+/).reject { |word| generic_name_word?(word) }
      words.join(" ").presence
    end

    def trade_hint_from_name
      words = trade_name.split(/\s+/).map(&:downcase)
      words.reject { |word| generic_name_word?(word) || word.length < 4 }.first&.then do |word|
        word.capitalize
      end
    end

    def generic_name_word?(word)
      %w[
        the and services service group holdings enterprises solutions
        northwest pacific west western north south east
        wa washington vancouver portland
      ].include?(word.to_s.downcase)
    end

    def same_name?(left, right)
      left.to_s.gsub(/["\s]+/, " ").strip.casecmp?(right.to_s.gsub(/["\s]+/, " ").strip)
    end

    def group(*terms)
      cleaned = terms.flatten.compact.map(&:to_s).reject(&:blank?).uniq
      return if cleaned.empty?

      "(#{cleaned.join(' OR ')})"
    end

    def join_tokens(*parts)
      parts.flatten.compact.join(" ")
    end

    def quoted(value)
      %("#{value.to_s.strip.gsub('"', "")}")
    end

    def useful_agent_name
      name = business.display_registered_agent_name.to_s.strip
      return if name.blank?
      return if name.match?(CORP_AGENT_PATTERN)
      return if corporate_entity_name?(name)

      name
    end

    def corporate_entity_name?(name)
      name.match?(/\b(LLC|INC|CORP|L\.L\.C\.|LTD|CO\.)\b/i) && name.split.size <= 5
    end

    def zip_code
      business.display_office_address.to_s[ZIP_PATTERN, 1]
    end

    def street_fragment
      addr = business.display_office_address.to_s.strip
      return if addr.blank?

      addr.split(",").first.to_s.strip.presence
    end

    def compact_address
      business.display_office_address.to_s
        .sub(/,\s*UNITED STATES\z/i, "")
        .gsub(/\s+/, " ")
        .strip
        .presence
    end
  end
end
