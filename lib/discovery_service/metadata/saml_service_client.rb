# frozen_string_literal: true

require 'logger'
require 'json'
require 'net/http'

module DiscoveryService
  module Metadata
    # For interaction with SAML Service
    module SAMLServiceClient
      def retrieve_entity_data(saml_service_url)
        url = URI.parse(saml_service_url)
        req = Net::HTTP::Get.new(url)
        with_saml_service_client(url) do |http|
          response = http.request(req)
          response.value # Raise exception on HTTP error
          JSON.parse(response.body, symbolize_names: true)
        end
      rescue Net::HTTPServerException => e
        log_error(e, saml_service_url)
        raise e
      end

      def with_saml_service_client(url)
        client = Net::HTTP.new(url.host, url.port)
        client.use_ssl = (url.scheme == 'https')
        client.read_timeout = 120
        logger.info "Invoking SAML Service (#{url})"
        client.start { |http| yield http }
      end

      def log_error(error, saml_service_url)
        logger.error "SAMLService HTTPServerException #{error.message} while" \
            " invoking #{saml_service_url}"
      end
    end
  end
end
