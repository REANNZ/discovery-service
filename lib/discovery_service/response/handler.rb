# frozen_string_literal: true

module DiscoveryService
  module Response
    # Module to handle user redirect / response
    module Handler
      # rubocop:disable Metrics/LineLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/PerceivedComplexity
      def handle_response(params)
        # Flow per sstc-saml-idp-discovery 2.4/5
        # Attempt to return to metadata valid return parameter else fallback
        # to default discovery service url specified for this SP
        return_url = params[:return]

        # This is more verbose than necessary so we can log what is going on
        # in detail with config disabled. Ideally over some period of time
        # we won't see any cases where a return URL will not be blocked
        # due to data already existing or being added to metadata and
        # this code will be simplified.
        if return_url&.present?
          if DiscoveryService.configuration[:environment][:restrict_return_url]
            if valid_return_url(params, return_url)
              logger.info(''"Return URL provided for
                          '#{params[:entityID]}' was valid"'')
              redirect_to(return_url, params)
            else
              logger.error(''"Return URL '#{return_url}' provided for
                           '#{params[:entityID]}' was invalid,
                           rejecting value"'')
              redirect to('/error/invalid_return_url')
            end
          else
            if valid_return_url(params, return_url)
              logger.info(''"Return URL '#{return_url}' provided for
                          '#{params[:entityID]}' was valid (config disabled)"'')
            else
              logger.error(''"Return URL '#{return_url}'
                           provided for '#{params[:entityID]}' was invalid,
                           would be rejected (config disabled)"'')
            end
            redirect_to(return_url, params)
          end
        else
          logger.info(''"Return URL not provided in
                      query for '#{params[:entityID]}'"'')
          return_url = default_discovery_response(params)
          return redirect_to(return_url, params) if return_url

          logger.info("No default return URL for '#{params[:entityID]}'")
          status 404
        end
      end
      # rubocop:enable

      private

      def valid_return_url(params, return_url)
        # Per sstc-saml-idp-discovery the query path is not relevant
        # remove it if it exists in the return_url
        ru = return_url [/^[^\?]+/]
        @entity_cache
          .all_discovery_response(params[:group],
                                  params[:entityID])&.include?(ru)
      end

      def default_discovery_response(params)
        @entity_cache.default_discovery_response(params[:group],
                                                 params[:entityID])
      end

      def redirect_to(return_url, params)
        redirect to(sp_response_url(return_url, params[:returnIDParam],
                                    params[:user_idp]))
      end

      def sp_response_url(return_url, param_key, selected_idp)
        url = URI.parse(return_url)
        query_opts = URI.decode_www_form(url.query || '')

        if selected_idp
          key = param_key || :entityID
          query_opts << [key, selected_idp]
        end

        url.query = URI.encode_www_form(query_opts)
        url.to_s
      end
    end
  end
end
