# frozen_string_literal: true

require 'json'
require 'active_support/core_ext/hash'

module DiscoveryService
  module Persistence
    # Class to handle storage / retrieval of entities
    class EntityCache
      include DiscoveryService::Persistence::Keys

      def initialize
        @redis = Redis::Namespace.new(:discovery_service, redis: Redis.new)
      end

      EXPIRY_IN_SECONDS = 28.days.to_i

      def entities(group)
        @redis.get(entities_key(group))
      end

      def entities_as_hash(group)
        build_entities(entities(group)) if entities_exist?(group)
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
        JSON.parse(entities_as_string, symbolize_names: true).stringify_keys
      end

      def to_hash(entities)
        Hash[entities.map { |e| [e[:entity_id], e.except(:entity_id)] }]
      end
    end
  end
end
