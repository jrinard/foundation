# frozen_string_literal: true

module Discovery
  module Sources
    class Catalog
      Entry = Struct.new(:key, :label, keyword_init: true)

      ENTRIES = [
        Entry.new(key: :wa_sos, label: Discovery::GemSources.label_for(DiscoveryBusiness::SOURCE_WA_SOS)),
        Entry.new(key: :data_axel, label: Discovery::GemSources.label_for(DiscoveryBusiness::SOURCE_DATA_AXEL))
      ].freeze

      def self.all
        ENTRIES
      end

      def self.label_for(key)
        entry = ENTRIES.find { |item| item.key.to_s == key.to_s }
        entry&.label || key.to_s.humanize
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
        when :data_axel
          organization.data_axel_discovery_source.enabled?
        else
          false
        end
      end
    end
  end
end
