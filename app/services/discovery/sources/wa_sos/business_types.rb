# frozen_string_literal: true

module Discovery
  module Sources
    module WaSos
      module BusinessTypes
        DEFAULT_ID = "65"

        OPTIONS = [
          ["FOREIGN BANK CORPORATION", "14"],
          ["FOREIGN BANK LIMITED LIABILITY COMPANY", "15"],
          ["FOREIGN COOPERATIVE ASSOCIATION", "16"],
          ["FOREIGN CREDIT UNION", "17"],
          ["FOREIGN INSURANCE COMPANY", "19"],
          ["FOREIGN LIMITED LIABILITY COMPANY", "20"],
          ["FOREIGN LIMITED LIABILITY LIMITED PARTNERSHIP", "21"],
          ["FOREIGN LIMITED LIABILITY PARTNERSHIP", "22"],
          ["FOREIGN LIMITED PARTNERSHIP", "23"],
          ["FOREIGN MASSACHUSETTS TRUST", "24"],
          ["FOREIGN NAME REGISTRATION", "25"],
          ["FOREIGN NONPROFIT CORPORATION", "26"],
          ["FOREIGN NONPROFIT PROFESSIONAL SERVICE CORPORATION", "27"],
          ["FOREIGN PROFESSIONAL LIMITED LIABILITY COMPANY", "33"],
          ["FOREIGN PROFESSIONAL LIMITED LIABILITY PARTNERSHIP", "35"],
          ["FOREIGN PROFESSIONAL SERVICE CORPORATION", "37"],
          ["FOREIGN PROFIT CORPORATION", "38"],
          ["FOREIGN PUBLIC UTILITY CORPORATION", "39"],
          ["FOREIGN SAVINGS AND LOAN ASSOCIATION", "40"],
          ["JOINT MUNICIPAL UTILITY SERVICE", "43"],
          ["MILITARY CORPORATION", "44"],
          ["WA ASSOCIATION UNDER FISH MARKETING ACT", "54"],
          ["WA BANK CORPORATION", "55"],
          ["WA BANK LIMITED LIABILITY COMPANY", "56"],
          ["WA BUILDING SOCIETY COMPOSED OF FRATERNAL MEMBERS", "57"],
          ["WA COOPERATIVE ASSOCIATION", "58"],
          ["WA CORP SOLE", "59"],
          ["WA CREDIT UNION", "60"],
          ["WA EMPLOYEE COOPERATIVE", "61"],
          ["WA FRATERNAL SOCIETY", "62"],
          ["WA GRANGE", "63"],
          ["WA INSURANCE COMPANY", "64"],
          ["WA LIMITED LIABILITY COMPANY", "65"],
          ["WA LIMITED LIABILITY LIMITED PARTNERSHIP", "67"],
          ["WA LIMITED LIABILITY PARTNERSHIP", "68"],
          ["WA LIMITED PARTNERSHIP", "69"],
          ["WA MASSACHUSETTS TRUST", "71"],
          ["WA MISCELLANEOUS AND MUTUAL CORPORATION", "72"],
          ["WA NONPROFIT CORPORATION", "73"],
          ["WA NONPROFIT PROFESSIONAL SERVICE CORPORATION", "74"],
          ["WA PROFESSIONAL LIMITED LIABILITY COMPANY", "79"],
          ["WA PROFESSIONAL LIMITED LIABILITY PARTNERSHIP", "76"],
          ["WA PROFESSIONAL SERVICE CORPORATION", "85"],
          ["WA PROFIT CORPORATION", "86"],
          ["WA PUBLIC UTILITY CORPORATION", "88"],
          ["WA SAVINGS AND LOAN ASSOCIATION", "89"],
          ["WA SOCIAL PURPOSE CORPORATION", "90"]
        ].freeze

        TYPE_SHORT_SUFFIXES = [
          ["PROFESSIONAL LIMITED LIABILITY LIMITED PARTNERSHIP", "PLLLP"],
          ["LIMITED LIABILITY LIMITED PARTNERSHIP", "LLLP"],
          ["PROFESSIONAL LIMITED LIABILITY PARTNERSHIP", "PLLP"],
          ["LIMITED LIABILITY PARTNERSHIP", "LLP"],
          ["PROFESSIONAL LIMITED LIABILITY COMPANY", "PLLC"],
          ["BANK LIMITED LIABILITY COMPANY", "Bank LLC"],
          ["LIMITED LIABILITY COMPANY", "LLC"],
          ["NONPROFIT PROFESSIONAL SERVICE CORPORATION", "Nonprofit PSC"],
          ["PROFESSIONAL SERVICE CORPORATION", "PSC"],
          ["NONPROFIT CORPORATION", "Nonprofit"],
          ["PROFIT CORPORATION", "Corp"],
          ["PUBLIC UTILITY CORPORATION", "PUC"],
          ["SAVINGS AND LOAN ASSOCIATION", "S&L"],
          ["LIMITED PARTNERSHIP", "LP"],
          ["CREDIT UNION", "CU"],
          ["INSURANCE COMPANY", "Insurance"],
          ["BANK CORPORATION", "Bank"],
          ["COOPERATIVE ASSOCIATION", "Co-op"],
          ["CORP SOLE", "Corp Sole"],
          ["MASSACHUSETTS TRUST", "Mass Trust"],
          ["SOCIAL PURPOSE CORPORATION", "SPC"],
          ["NAME REGISTRATION", "Name Reg"],
          ["MISCELLANEOUS AND MUTUAL CORPORATION", "Misc Corp"]
        ].freeze

        def self.short_label(full_name)
          text = full_name.to_s.strip
          return "" if text.blank?

          TYPE_SHORT_SUFFIXES.each do |suffix, abbr|
            return abbr if text.match?(/\b#{Regexp.escape(suffix)}\z/i)
          end

          text
        end
      end
    end
  end
end
