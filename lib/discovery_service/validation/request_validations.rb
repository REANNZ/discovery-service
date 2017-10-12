# frozen_string_literal: true

module DiscoveryService
  module Validation
    # Module to handle request validation
    module RequestValidations
      URL_SAFE_BASE_64_ALPHABET = /^[a-zA-Z0-9_-]+$/
      VALID_URI_REGEX = /\A#{URI::DEFAULT_PARSER.make_regexp}\z/
      IDP_DISCOVERY_SINGLE_PROTOCOL =
        'urn:oasis:names:tc:SAML:profiles:SSO:idp-discovery-protocol:single'

      def uri?(value)
        value && value =~ VALID_URI_REGEX
      end

      def passive?(params)
        params[:isPassive] && params[:isPassive] == 'true'
      end

      def valid_group_name?(group)
        group =~ URL_SAFE_BASE_64_ALPHABET
      end

      def valid_policy?(policy)
        policy.nil? || policy == IDP_DISCOVERY_SINGLE_PROTOCOL
      end

      def valid_params?
        valid_group_name?(params[:group]) &&
          (passive?(params) || uri?(params[:user_idp])) &&
          uri?(params[:entityID]) &&
          valid_policy?(params[:policy])
      end
    end
  end
end
