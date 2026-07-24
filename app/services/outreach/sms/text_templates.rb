# frozen_string_literal: true

module Outreach
  module Sms
    class TextTemplates
      Entry = Struct.new(:key, :label, :body, :intent, keyword_init: true)
      Group = Struct.new(:intent, :label, :entries, keyword_init: true)

      CALENDLY_LINK = "https://calendly.com/lifespring-design/intro"
      OPT_OUT_FOOTER = "Reply STOP to opt out."

      OPENING = :opening
      RESPONSE = :response

      INTENT_DEFAULT_RESPONSE = {
        "yes" => "qualify",
        "maybe" => "maybe",
        "not_right_now" => "not_right_now",
        "have_someone" => "have_someone",
        "how_get_number" => "how_get_number",
        "who_are_you" => "who_are_you",
        "online_presence" => "online_presence",
        "pricing" => "pricing",
        "no_thanks" => "no_thanks"
      }.freeze

      def self.for(customer:, user: nil)
        new(customer: customer, user: user)
      end

      def self.default_key
        "local_web_dev"
      end

      def self.response_default_key
        "qualify"
      end

      def self.default_key_for_intent(intent)
        INTENT_DEFAULT_RESPONSE.fetch(intent.to_s, response_default_key)
      end

      def initialize(customer:, user: nil)
        @customer = customer
        @user = user
        @discovery = customer.linked_discovery_business
      end

      def opening_entries
        [
          Entry.new(key: "local_web_dev", label: "Local Web Dev", body: opening_body, intent: "opening"),
          Entry.new(key: "specific", label: "Specific", body: specific_body, intent: "opening")
        ]
      end

      def response_groups
        [
          Group.new(
            intent: "yes",
            label: "Yes",
            entries: [
              entry("book_coffee", "Book coffee", book_coffee_body, "yes"),
              entry("qualify", "Learn business", qualify_body, "yes"),
              entry("calendar", "Calendar", CALENDLY_LINK, "yes")
            ]
          ),
          Group.new(
            intent: "maybe",
            label: "Maybe / timing",
            entries: [
              entry("maybe", "Identify challenge", maybe_body, "maybe"),
              entry("not_right_now", "Follow up later", not_right_now_body, "maybe")
            ]
          ),
          Group.new(
            intent: "have_someone",
            label: "Already have someone",
            entries: [
              entry("have_someone", "Stay connected", have_someone_body, "have_someone")
            ]
          ),
          Group.new(
            intent: "questions",
            label: "Questions",
            entries: [
              entry("how_get_number", "How got my #?", how_get_number_body, "how_get_number"),
              entry("who_are_you", "Who are you?", who_are_you_body, "who_are_you"),
              entry("online_presence", "Online presence?", online_presence_body, "online_presence"),
              entry("pricing", "Pricing", pricing_body, "pricing")
            ]
          ),
          Group.new(
            intent: "no_thanks",
            label: "No thanks",
            entries: [
              entry("no_thanks", "Close conversation", no_thanks_body, "no_thanks")
            ]
          )
        ]
      end

      def response_entries
        response_groups.flat_map(&:entries)
      end

      def entries_for(set:)
        set == RESPONSE ? response_entries : opening_entries
      end

      def body_for(key, set: OPENING)
        entries_for(set: set).find { |entry| entry.key == key.to_s }&.body
      end

      def opening_body
        first = first_name

        with_opt_out_footer(<<~TEXT.strip)
          Hi #{first}, This is Josh. I'm a local web developer here in Battle Ground. I was wondering if you need someone to help with your website or online presence. If so, I'd love to buy you a coffee and learn more about your business to see if I can help.
        TEXT
      end

      private

      def with_opt_out_footer(body)
        "#{body}\n\n#{OPT_OUT_FOOTER}"
      end

      def entry(key, label, body, intent)
        Entry.new(key: key, label: label, body: body, intent: intent)
      end

      def qualify_body
        <<~TEXT.strip
          That's great! I'd love to learn more. What kind of business are you in, and what's been the biggest challenge with your website or online presence?
        TEXT
      end

      def book_coffee_body
        <<~TEXT.strip
          Awesome! I'd love to hear more about your business. Would sometime next week work to grab a coffee?
        TEXT
      end

      def maybe_body
        <<~TEXT.strip
          No worries. Is there something specific you've been thinking about improving, or are you just not ready yet?
        TEXT
      end

      def not_right_now_body
        <<~TEXT.strip
          Totally understand. Starting or running a business keeps you busy. If things change down the road, I'd be happy to be a resource.
        TEXT
      end

      def have_someone_body
        <<~TEXT.strip
          That's great to hear! It's always good to have someone you trust. If you ever need another opinion or your current developer gets backed up, feel free to reach out. I'm always happy to help.
        TEXT
      end

      def how_get_number_body
        <<~TEXT.strip
          I came across your business while looking for local businesses in the area. I like connecting with local business owners to see if I can be a resource. If you'd rather not hear from me again, just let me know.
        TEXT
      end

      def who_are_you_body
        <<~TEXT.strip
          My name's Josh. I'm a local web developer in Battle Ground. I work with small businesses on websites, branding, software, and online marketing.
        TEXT
      end

      def online_presence_body
        <<~TEXT.strip
          Things like your website, Google Business Profile, search rankings, online reviews, branding, and other tools that help customers find and trust your business.
        TEXT
      end

      def pricing_body
        <<~TEXT.strip
          It really depends on what your business needs. I like partnering with businesses to be a partner, helping with their website, branding, online reputation as they grow. If you're interested, I'd love to buy you a coffee, learn more about your business, and see if we're a good fit.
        TEXT
      end

      def no_thanks_body
        <<~TEXT.strip
          No problem at all. Thanks for getting back to me, and I wish you the best with your business!
        TEXT
      end

      def specific_body
        first = first_name
        business = business_name
        gap = top_gap_label
        sender = sender_name

        with_opt_out_footer(<<~TEXT.strip)
          Hi #{first}, #{sender} here from LifeSpring Design. I was looking at #{business} and noticed #{gap}. We help local businesses tighten that up — open to a quick text back if you want a few ideas?
        TEXT
      end

      def top_gap_label
        return "a few gaps in your online presence" unless @discovery

        gaps = []
        gaps << "your website could use a refresh" if @discovery.website_check_status == DiscoveryBusiness::CHECK_MISSING
        gaps << "your Google reviews could be stronger" if @discovery.places_check_status == DiscoveryBusiness::CHECK_MISSING
        gaps << "your social presence is pretty quiet" if @discovery.facebook_check_status == DiscoveryBusiness::CHECK_MISSING

        gaps.first || "a few gaps in your online presence"
      end

      def first_name
        name = @customer.name.to_s.strip
        return "there" if name.blank?

        name.split(/\s+/).first
      end

      def business_name
        @customer.name.presence || @discovery&.business_name.presence || "your business"
      end

      def sender_name
        @user&.name.presence || "LifeSpring Design"
      end
    end
  end
end
