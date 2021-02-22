# frozen_string_literal: true

module DiscoveryService
  module Response
    # Module to handle user redirect / response
    module Handler
      def handle_response(params)
        # Flow per sstc-saml-idp-discovery 2.4/5
        # Attempt to return to metadata valid return parameter else fallback
        # to default discovery service url specified for this SP
        unless known_sp?(params)
          logger.info('Unable to locate the entityID '\
            "'#{params[:entityID]}', halting response")
          return redirect to('/error/invalid_entity_id')
        end

        if params[:return]&.present?
          handle_return_url(params)
        else
          handle_no_return_url(params)
        end
      end

      private

      def known_sp?(params)
        @entity_cache.entity_exists?(params[:group], params[:entityID])
      end

      def handle_return_url(params)
        return_url = params[:return]
        if valid_return_url(params)
          logger.info('Return URL provided for '\
                      "'#{params[:entityID]}' was valid")
          redirect_to(return_url, params)
        else
          logger.error("Return URL '#{return_url}' provided for "\
                       "'#{params[:entityID]}' was invalid, rejecting value")
          redirect to('/error/invalid_return_url')
        end
      end

      def handle_no_return_url(params)
        logger.info('Return URL not provided in '\
                    "query for '#{params[:entityID]}'")
        return_url = default_discovery_response(params)
        return redirect_to(return_url, params) if return_url

        logger.info("No default return URL for '#{params[:entityID]}'")
        status 404
      end

      def valid_return_url(params)
        return_url = params[:return]
        # Per sstc-saml-idp-discovery the query path is not relevant
        # remove it if it exists in the return_url
        ru = return_url[/^[^?]+/]
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
