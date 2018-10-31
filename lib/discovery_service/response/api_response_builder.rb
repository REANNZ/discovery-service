# frozen_string_literal: true

module DiscoveryService
  module Response
    # Module to build response for the API.
    module APIResponseBuilder
      def build_api_response(entities)
        result = {}
        result[:identity_providers] = []
        entities.each do |entity_id, entity|
          next unless entity[:tags].include?('idp')

          fields = entity.slice(:names, :logos, :tags,
                                :single_sign_on_endpoints)
          result[:identity_providers] << { entity_id: entity_id }.merge(fields)
        end
        result
      end
    end
  end
end
