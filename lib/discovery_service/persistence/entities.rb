require 'json'
require 'active_support/core_ext/hash'
require 'discovery_service/persistence/keys'

module DiscoveryService
  module Persistence
    # Collection of methods to build entity data (from / to) redis
    module Entities
      include DiscoveryService::Persistence::Keys

      EXPIRY_IN_SECONDS = 28.days.to_i

      def entities(group)
        @redis.get(entities_key(group))
      end

      def entities_exist?(group)
        @redis.exists(entities_key(group))
      end

      def save_entities(entities, group)
        @redis.set(entities_key(group), to_hash(entities).to_json)
      end

      def group_page_exists?(group)
        @redis.exists(group_page_key(group))
      end

      def group_page(group)
        @redis.get(group_page_key(group))
      end

      def save_group_page(group, page)
        @redis.set(group_page_key(group), page)
      end

      def update_expiry(group)
        logger.info("Setting #{group_page_key(group)} expiry: "\
          "#{EXPIRY_IN_SECONDS} seconds")
        logger.info("Setting #{entities_key(group)} expiry: "\
          "#{EXPIRY_IN_SECONDS} seconds")
        @redis.expire(group_page_key(group), EXPIRY_IN_SECONDS)
        @redis.expire(entities_key(group), EXPIRY_IN_SECONDS)
      end

      # pre: @redis.get(entities_key(group)) != nil
      def entities_diff(group, entities)
        stored_entities = build_entities(@redis.get(entities_key(group)))
        HashDiff.diff(stored_entities, to_hash(entities))
      end

      def discovery_response(group, entity_id)
        return nil unless entities_exist?(group)
        entities = build_entities(entities(group))
        return nil unless entities.key?(entity_id) &&
                          entities[entity_id].key?(:discovery_response)
        entities[entity_id][:discovery_response]
      end

      private

      def build_entities(entities_as_string)
        stored_entities_as_json = JSON.parse(entities_as_string)
        stored_entities_as_json.each { |_k, v| v.symbolize_keys! }
      end

      def to_hash(entities)
        hash = Hash[entities.map { |e| [e[:entity_id], e.except(:entity_id)] }]
        hash.each { |_k, v| v.symbolize_keys! }
      end
    end
  end
end
