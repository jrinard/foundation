# frozen_string_literal: true

module Discovery
  module Sources
    class Catalog
      Entry = Struct.new(:key, :label, keyword_init: true)

      ENTRIES = [
        Entry.new(key: :wa_sos, label: "Washington Secretary of State")
      ].freeze

      def self.all
        ENTRIES
      end

      def self.enabled_for(organization)
        all.select do |entry|
          source_enabled?(organization, entry.key)
        end
      end

      def self.source_enabled?(organization, key)
        case key.to_sym
        when :wa_sos
          organization.wa_sos_discovery_source.enabled?
        else
          false
        end
      end
    end
  end
end
