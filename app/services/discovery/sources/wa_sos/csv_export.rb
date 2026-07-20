# frozen_string_literal: true

module Discovery
  module Sources
    module WaSos
      class CsvExport
        ENDPOINT = "/api/BusinessSearch/GetAdvanceBusinessSearchListForOnlineCsvExport"

        def self.key
          :wa_sos
        end

        def initialize(
          business_type_id: BusinessTypes::DEFAULT_ID,
          business_status_id: "1",
          start_date:,
          end_date: "",
          search_entity_name: nil,
          page_id: "1",
          page_count: "25"
        )
          @business_type_id = business_type_id.to_s
          @business_status_id = business_status_id.to_s
          @start_date = start_date.to_s
          @end_date = end_date.to_s
          @search_entity_name = search_entity_name.to_s.strip
          @page_id = page_id.to_s
          @page_count = page_count.to_s
        end

        def fetch
          Client.post_form(
            ENDPOINT,
            payload,
            accept: "application/octet-stream"
          )
        end

        private

        # Payload mirrors the working browser form POST from CCFS advanced search CSV export.
        # PrincipalAddress is WA-wide only — funnel filters (city, etc.) run after fetch.
        def payload
          {
            "Type" => "Agent",
            "BusinessStatusID" => @business_status_id,
            "SearchEntityName" => @search_entity_name,
            "SearchType" => @search_entity_name.present? ? "Contains" : "",
            "BusinessTypeID" => @business_type_id,
            "AgentName" => "",
            "PrincipalName" => "",
            "StartDateOfIncorporation" => @start_date,
            "EndDateOfIncorporation" => @end_date,
            "ExpirationDate" => "",
            "IsSearch" => "true",
            "IsShowAdvanceSearch" => "true",
            "AgentAddress[IsAddressSame]" => "false",
            "AgentAddress[IsValidAddress]" => "false",
            "AgentAddress[isUserNonCommercialRegisteredAgent]" => "false",
            "AgentAddress[IsInvalidState]" => "false",
            "AgentAddress[baseEntity][FilerID]" => "0",
            "AgentAddress[baseEntity][UserID]" => "0",
            "AgentAddress[baseEntity][CreatedBy]" => "0",
            "AgentAddress[baseEntity][ModifiedBy]" => "0",
            "AgentAddress[FullAddress]" => ", WA, USA",
            "AgentAddress[ID]" => "0",
            "AgentAddress[State]" => "WA",
            "AgentAddress[Country]" => "USA",
            "PrincipalAddress[IsAddressSame]" => "false",
            "PrincipalAddress[IsValidAddress]" => "false",
            "PrincipalAddress[isUserNonCommercialRegisteredAgent]" => "false",
            "PrincipalAddress[IsInvalidState]" => "false",
            "PrincipalAddress[baseEntity][FilerID]" => "0",
            "PrincipalAddress[baseEntity][UserID]" => "0",
            "PrincipalAddress[baseEntity][CreatedBy]" => "0",
            "PrincipalAddress[baseEntity][ModifiedBy]" => "0",
            "PrincipalAddress[FullAddress]" => ", WA, USA",
            "PrincipalAddress[ID]" => "0",
            "PrincipalAddress[Country]" => "USA",
            "NonProfit[IsNonProfitEnabled]" => "false",
            "NonProfit[chkSearchByIsHostHome]" => "false",
            "NonProfit[chkSearchByIsPublicBenefitNonProfit]" => "false",
            "NonProfit[chkSearchByIsCharitableNonProfit]" => "false",
            "NonProfit[chkSearchByIsGrossRevenueNonProfit]" => "false",
            "NonProfit[chkSearchByIsHasMembers]" => "false",
            "NonProfit[chkSearchByIsHasFEIN]" => "false",
            "NonProfit[FEINNoSearch]" => "",
            "PageID" => @page_id,
            "PageCount" => @page_count
          }
        end
      end
    end
  end
end
