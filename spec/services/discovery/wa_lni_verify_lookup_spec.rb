# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::WaLniVerifyLookup do
  let(:organization) { create(:organization, discovery_enabled: true) }

  before { Current.organization = organization }

  def business_for(**attrs)
    create(
      :discovery_business,
      organization: organization,
      business_name: "PRIME CONSTRUCTION NW LLC",
      external_id: "604325889",
      city: "Port Orchard",
      **attrs
    )
  end

  describe ".search" do
    it "returns ranked L&I matches for the business name" do
      payload = {
        "d" => {
          "SearchResult" => [
            {
              "Ubi" => "999999999",
              "LicenseId" => "OTHER123",
              "BusinessName" => "OTHER CO",
              "ContractorType" => "Construction Contractor",
              "ContractorGroup" => "Construction Contractor",
              "City" => "SEATTLE",
              "State" => "WA",
              "ZipCode" => "98101",
              "Status" => "View Details",
              "OverallRank" => 100
            },
            {
              "Ubi" => "604325889",
              "LicenseId" => "PRIMECN822PA",
              "BusinessName" => "PRIME CONSTRUCTION NW",
              "ContractorType" => "Construction Contractor",
              "ContractorGroup" => "Construction Contractor",
              "City" => "PORT ORCHARD",
              "State" => "WA",
              "ZipCode" => "98366",
              "Status" => "Inactive",
              "OverallRank" => 539
            }
          ]
        }
      }

      allow_any_instance_of(described_class).to receive(:post_json).and_return(payload)

      result = described_class.search(discovery_business: business_for)

      expect(result.ok).to be(true)
      expect(result.results.size).to eq(1)
      expect(result.results.first[:ubi]).to eq("999999999")
      expect(result.results.first[:business_name]).to eq("OTHER CO")
      expect(result.results.first[:detail_url]).to include("Detail.aspx")
    end

    it "returns only the UBI match when an active match shares the business UBI" do
      payload = {
        "d" => {
          "SearchResult" => [
            {
              "Ubi" => "999999999",
              "LicenseId" => "OTHER123",
              "BusinessName" => "OTHER CO",
              "ContractorType" => "Construction Contractor",
              "City" => "SEATTLE",
              "State" => "WA",
              "ZipCode" => "98101",
              "Status" => "View Details",
              "OverallRank" => 100
            },
            {
              "Ubi" => "604325889",
              "LicenseId" => "PRIMECN822PA",
              "BusinessName" => "PRIME CONSTRUCTION NW",
              "ContractorType" => "Construction Contractor",
              "City" => "PORT ORCHARD",
              "State" => "WA",
              "ZipCode" => "98366",
              "Status" => "View Details",
              "OverallRank" => 539
            }
          ]
        }
      }

      allow_any_instance_of(described_class).to receive(:post_json).and_return(payload)

      result = described_class.search(discovery_business: business_for)

      expect(result.ok).to be(true)
      expect(result.results.size).to eq(1)
      expect(result.results.first[:ubi]).to eq("604325889")
      expect(result.results.first[:ubi_match]).to be(true)
    end

    it "excludes inactive L&I matches from search results" do
      payload = {
        "d" => {
          "SearchResult" => [
            {
              "Ubi" => "604325889",
              "LicenseId" => "PRIMECN822PA",
              "BusinessName" => "PRIME CONSTRUCTION NW",
              "ContractorType" => "Construction Contractor",
              "City" => "PORT ORCHARD",
              "State" => "WA",
              "ZipCode" => "98366",
              "Status" => "Inactive",
              "OverallRank" => 100
            }
          ]
        }
      }

      allow_any_instance_of(described_class).to receive(:post_json).and_return(payload)

      result = described_class.search(discovery_business: business_for)

      expect(result.ok).to be(true)
      expect(result.results).to be_empty
      expect(result.message).to include("No active L&I matches")
    end

    it "searches by name only to match the public L&I site (no CityFilter)" do
      business = business_for(city: "Vancouver")
      captured_payload = nil

      allow_any_instance_of(described_class).to receive(:post_json) do |_instance, _url, body|
        captured_payload = body
        { "d" => { "SearchResult" => [] } }
      end

      described_class.search(discovery_business: business)

      expect(captured_payload.dig(:dtoSrch, :searchCat)).to eq("Name")
      expect(captured_payload.dig(:dtoSrch, :searchText)).to eq("PRIME CONSTRUCTION NW LLC")
      expect(captured_payload.dig(:dtoSrch, :firstSearch)).to eq(1)
      expect(captured_payload.dig(:dtoSrch, :CityFilter)).to be_nil
    end

    it "finds an active match even when SOS city differs from the L&I license city" do
      payload = {
        "d" => {
          "SearchResult" => [
            {
              "Ubi" => "605458621",
              "LicenseId" => "ASPENGN766L6",
              "BusinessName" => "ASPEN GROUP NW LLC",
              "ContractorType" => "Construction Contractor",
              "City" => "VANCOUVER",
              "State" => "WA",
              "ZipCode" => "98684",
              "Status" => "View Details",
              "OverallRank" => 5000
            }
          ]
        }
      }

      allow_any_instance_of(described_class).to receive(:post_json).and_return(payload)

      result = described_class.search(
        discovery_business: business_for(
          business_name: "ASPEN GROUP NW LLC",
          external_id: "605458621",
          city: "Seattle"
        )
      )

      expect(result.ok).to be(true)
      expect(result.results.size).to eq(1)
      expect(result.results.first[:business_name]).to eq("ASPEN GROUP NW LLC")
      expect(result.results.first[:ubi_match]).to be(true)
    end
  end

  describe ".details" do
    it "returns phone and address from contractor details" do
      payload = {
        "d" => {
          "ReturnValue" => {
            "Contractor" => {
              "LicenseNumber" => "PRIMECN822PA",
              "UbiNumber" => "604325889",
              "BusinessName" => "PRIME CONSTRUCTION NW",
              "PhoneNumber" => "3603401939",
              "Address1" => "4826 SE SLEEPY HOLLOW CT",
              "Address2" => "",
              "City" => "PORT ORCHARD",
              "State" => "WA",
              "Zip" => "98366",
              "LicenseType" => "Construction Contractor",
              "SpecialtyName1" => "GENERAL",
              "StatusDescription" => "EXPIRED",
              "ParentCompany" => "PRIME CONSTRUCTION NW LLC",
              "BusinesOwners" => [
                { "Name" => "COOPER, MICHAEL ALAN", "RoleDescription" => "PARTNER/MEMBER" }
              ]
            },
            "Employer" => {
              "EmployerDetails" => [
                {
                  "AccountInfoBusinessNameList" => [
                    { "BusinessDbaName" => "PRIME CONSTRUCTION NW" }
                  ],
                  "AccountInfoStatusList" => [
                    { "AccountRepresentative" => "T1 / REP (360) 902-5555 - Email: rep@lni.wa.gov" }
                  ]
                }
              ]
            }
          }
        }
      }

      allow_any_instance_of(described_class).to receive(:post_json).and_return(payload)

      result = described_class.details(ubi: "604325889", license: "PRIMECN822PA")

      expect(result.ok).to be(true)
      expect(result.details[:phone]).to eq("(360) 340-1939")
      expect(result.details[:vertical_classification]).to eq("Construction Contractor")
      expect(result.details[:vertical_source]).to eq("GENERAL · Construction Contractor")
      expect(result.details[:parent_company]).to eq("PRIME CONSTRUCTION NW LLC")
      expect(result.details[:dba_name]).to eq("PRIME CONSTRUCTION NW")
      expect(result.details[:employer_rep]).to include("rep@lni.wa.gov")
      expect(result.details[:owners].first[:name]).to include("COOPER")
    end

    it "returns employer-only details when no contractor license is on file" do
      payload = {
        "d" => {
          "ReturnValue" => {
            "Contractor" => {
              "LicenseNumber" => nil,
              "UbiNumber" => nil,
              "BusinessName" => nil,
              "PhoneNumber" => nil,
              "IsLoaded" => false
            },
            "Employer" => {
              "EmployerBussinessDetails" => {
                "LegalName" => "VOLUME11 LLC",
                "BusinessId" => "605396926",
                "CityName" => "RIDGEFIELD",
                "ZipCode" => "986425479",
                "State" => "WA",
                "Address" => "778 N 49TH AVE"
              }
            }
          }
        }
      }

      allow_any_instance_of(described_class).to receive(:post_json).and_return(payload)

      result = described_class.details(ubi: "605396926", license: "")

      expect(result.ok).to be(true)
      expect(result.details[:business_name]).to eq("VOLUME11 LLC")
      expect(result.details[:ubi]).to eq("605396926")
      expect(result.details[:address]).to include("778 N 49TH AVE")
      expect(result.details[:address]).to include("RIDGEFIELD")
      expect(result.details[:phone]).to be_blank
    end
  end

  describe "vertical inference" do
    it "maps plumbing specialty to Plumbing vertical" do
      expect(
        Discovery::Verticals.infer_from_lni(specialty: "PLUMBING", license_type: "Construction Contractor")
      ).to eq("Plumbing")
    end

    it "maps general construction license to Construction Contractor vertical" do
      expect(
        Discovery::Verticals.infer_from_lni(specialty: "GENERAL", license_type: "Construction Contractor")
      ).to eq("Construction Contractor")
    end

    it "maps remodel specialty to Remodeling vertical" do
      expect(
        Discovery::Verticals.infer_from_lni(specialty: "REMODEL", license_type: "Construction Contractor")
      ).to eq("Remodeling")
    end
  end
end
