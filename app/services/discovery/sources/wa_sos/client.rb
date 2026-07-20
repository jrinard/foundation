# frozen_string_literal: true

require "net/http"
require "uri"

module Discovery
  module Sources
    module WaSos
      class Client
        ORIGIN = "https://ccfs.sos.wa.gov"
        REFERER = "https://ccfs.sos.wa.gov/"
        BASE_URL = "https://ccfs-api.prod.sos.wa.gov"

        Response = Struct.new(:status, :body, :parsed, :content_type, keyword_init: true) do
          def success?
            status.to_i.between?(200, 299)
          end
        end

        def self.post_form(path, fields, accept: "application/json, text/plain, */*")
          uri = URI("#{BASE_URL}#{path}")
          request = Net::HTTP::Post.new(uri)
          request["Accept"] = accept
          request["Content-Type"] = "application/x-www-form-urlencoded"
          request["Origin"] = ORIGIN
          request["Referer"] = REFERER
          request["User-Agent"] = "Foundation Discovery/1.0"
          request.body = URI.encode_www_form(fields)

          execute(uri, request)
        end

        def self.execute(uri, request)
          response = Net::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: true,
            open_timeout: 30,
            read_timeout: 120
          ) do |http|
            http.request(request)
          end

          body = response.body.to_s

          Response.new(
            status: response.code.to_i,
            body: body,
            parsed: nil,
            content_type: response["Content-Type"]
          )
        end
      end
    end
  end
end
