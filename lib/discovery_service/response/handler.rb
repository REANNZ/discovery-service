# frozen_string_literal: true

module DiscoveryService
  module Response
    # Module to handle user redirect / response
    module Handler
      def handle_response(params)
        if params[:return]
          redirect_to(params[:return], params)
        elsif discovery_response(params)
          redirect_to(discovery_response(params), params)
        else
          status 404
        end
      end

      private

      def discovery_response(params)
        @entity_cache.discovery_response(params[:group], params[:entityID])
      end

      def redirect_to(return_url, params)
        redirect to(sp_response_url(return_url, params[:returnIDParam],
                                    params[:user_idp]))
      end

      def sp_response_url(return_url, param_key, selected_idp)
        url = URI.parse(return_url)
        key = param_key || :entityID
        query_opts = URI.decode_www_form(url.query || '') << [key, selected_idp]
        url.query = URI.encode_www_form(query_opts)
        url.to_s
      end
    end
  end
end
