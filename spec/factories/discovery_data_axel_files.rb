# frozen_string_literal: true

FactoryBot.define do
  factory :discovery_data_axel_file do
    organization
    filename { "Summary-test.csv" }
    byte_size { raw_csv.bytesize }
    row_count { 1 }
    raw_csv do
      <<~CSV
        "Company Name","Executive First Name","Executive Last Name","Address","City","State","ZIP Code","IUSA Number","Phone Number Combined","Primary SIC Description","Legal Name"
        "Acme LLC","Jane","Doe","123 Main St","Vancouver","WA","98660","82-277-7860","(360) 555-0100","Construction Companies","ACME LLC"
      CSV
    end

    trait :many_rows do
      transient do
        row_total { 20 }
      end

      after(:build) do |file, evaluator|
        header = '"Company Name","Executive First Name","Executive Last Name","Address","City","State","ZIP Code","IUSA Number","Phone Number Combined","Primary SIC Description","Legal Name"'
        rows = (1..evaluator.row_total).map do |index|
          %("Business #{index} LLC","Jane","Doe","123 Main St","Vancouver","WA","98660","82-277-786#{index}","(360) 555-010#{index}","Construction Companies","BUSINESS #{index} LLC")
        end
        file.raw_csv = ([header] + rows).join("\n")
        file.byte_size = file.raw_csv.bytesize
        file.row_count = evaluator.row_total
      end
    end
  end
end
