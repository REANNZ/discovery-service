# frozen_string_literal: true

module DiscoveryService
  module Persistence
    # Collection of methods to build redis keys
    module Keys
      def group_page_key(group)
        "pages:group:#{group}"
      end

      def entities_key(group)
        "entities:#{group}"
      end
    end
  end
end
