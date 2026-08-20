# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::CreateDataAxelFile do
  let(:organization) { create(:organization) }
  let(:csv_body) do
    <<~CSV
      "Company Name","Executive First Name","Executive Last Name","Address","City","State","ZIP Code","IUSA Number","Phone Number Combined","Primary SIC Description","Legal Name"
      "Acme LLC","Jane","Doe","123 Main St","Vancouver","WA","98660","82-277-7860","(360) 555-0100","Construction Companies","ACME LLC"
    CSV
  end
  let(:upload) do
    file = Tempfile.new(["summary", ".csv"])
    file.write(csv_body)
    file.rewind
    ActionDispatch::Http::UploadedFile.new(
      tempfile: file,
      filename: "Summary-test.csv",
      type: "text/csv"
    )
  end

  it "creates a mountain gems file record" do
    result = described_class.call(organization: organization, upload: upload)

    expect(result).to be_success
    expect(result.file.filename).to eq("Summary-test.csv")
    expect(result.file.display_label).to eq("Summary-test")
    expect(result.file.row_count).to eq(1)
    expect(result.file.byte_size).to be_positive
  end

  it "stores an optional label" do
    result = described_class.call(organization: organization, upload: upload, label: "Vancouver list")

    expect(result).to be_success
    expect(result.file.label).to eq("Vancouver list")
    expect(result.file.display_label).to eq("Vancouver list")
  end

  it "returns an error when upload is missing" do
    result = described_class.call(organization: organization, upload: nil)

    expect(result).not_to be_success
    expect(result.errors).to include("Choose a CSV file to upload.")
  end
end
