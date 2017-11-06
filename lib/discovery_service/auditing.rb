# frozen_string_literal: true

module DiscoveryService
  # Provides capabilities for logging audit data for reporting purposes
  module Auditing
    def record_request(request, params)
      data = base_data(request, params)

      SecureRandom.urlsafe_base64.tap do |id|
        record_entry(data.merge(phase: 'request', unique_id: id))
      end
    end

    def record_manual_selection(request, params, unique_id)
      data = base_data(request, params).merge(selected_idp: params[:user_idp],
                                              selection_method: 'manual',
                                              unique_id: unique_id)

      record_entry(data.merge(phase: 'response'))
    end

    def record_cookie_selection(request, params, unique_id, idp)
      data = base_data(request, params).merge(selected_idp: idp,
                                              selection_method: 'cookie',
                                              unique_id: unique_id)

      record_entry(data.merge(phase: 'response'))
    end

    private

    def record_entry(data)
      json = JSON.generate(data)
      redis.lpush('audit', json)
    end

    def base_data(request, params)
      {
        user_agent: request.user_agent,
        ip: request.ip,
        initiating_sp: params[:entityID],
        timestamp: Time.now.utc.xmlschema,
        group: params[:group]
      }
    end
  end
end
