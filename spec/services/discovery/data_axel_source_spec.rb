# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::Sources::DataAxel::CsvParser do
  let(:csv_row) do
    <<~CSV
      "Company Name","Executive First Name","Executive Last Name","Address","City","State","ZIP Code","IUSA Number","Phone Number Combined","Primary SIC Description","Legal Name"
      "Acme LLC","Jane","Doe","123 Main St","Vancouver","WA","98660","82-277-7860","(360) 555-0100","Construction Companies","ACME LLC"
    CSV
  end

  it "normalizes Axel rows into SOS-shaped display columns" do
    row = described_class.parse(csv_row).first

    expect(row["Business Name"]).to eq("Acme LLC")
    expect(row["Reg Name"]).to eq("Jane Doe")
    expect(row["Office Address"]).to include("123 Main St")
    expect(row["Office Address"]).to include("Vancouver")
    expect(row["Business Type"]).to eq("Construction Companies")
    expect(row["UBI#"]).to eq("822777860")
    expect(row["Phone Number Combined"]).to eq("(360) 555-0100")
  end
end

RSpec.describe Discovery::Sources::DataAxelSettings do
  it "defaults to 15 rows" do
    settings = described_class.new
    expect(settings.row_limit).to eq(15)
    expect(settings.apply_row_window((1..20).to_a).size).to eq(15)
  end

  it "applies an inclusive row range when enabled" do
    settings = described_class.new(
      row_range_enabled: true,
      row_range_start: 3,
      row_range_end: 5
    )

    expect(settings.apply_row_window((1..10).to_a)).to eq([3, 4, 5])
  end
end

RSpec.describe Discovery::RunDataAxelSource do
  let(:organization) { create(:organization) }

  before do
    DiscoverySource.ensure_data_axel!(organization).update!(enabled: true)
    create(:discovery_data_axel_file, :many_rows, organization: organization, row_total: 20)
  end

  it "returns a limited row window from merged CSV files" do
    result = described_class.call(
      organization: organization,
      overrides: { row_limit: 15 }
    )

    expect(result.success?).to be(true)
    expect(result.rows.size).to eq(15)
    expect(result.all_rows.size).to be > 15
  end
end
