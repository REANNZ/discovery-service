require 'yaml'
require 'redis'
require 'redis-namespace'
require 'slim'
require 'discovery_service/metadata/entity_data_filter'
require 'discovery_service/metadata/saml_service_client'
require 'discovery_service/renderer/page_renderer'
require 'discovery_service/renderer/model/group'
require 'active_support/core_ext/numeric/time'
require 'hashdiff'

module DiscoveryService
  module Metadata
    # Retrieves and filters metadata from SAML service
    class Updater
      attr_accessor :logger
      include DiscoveryService::Metadata::SAMLServiceClient
      include DiscoveryService::Metadata::EntityDataFilter
      include DiscoveryService::Renderer::PageRenderer
      EXPIRY_IN_SECONDS = 28.days.to_i

      def initialize
        @logger = Logger.new($stderr)
        @redis = Redis::Namespace.new(:discovery_service, redis: Redis.new)
      end

      def update
        config = YAML.load_file('config/discovery_service.yml')
        raw_entities = retrieve_entity_data(config[:saml_service][:uri])
        grouped_entities = filter(raw_entities[:entities], config[:collections])
        grouped_entities.each do |group, entities|
          if !entities_exists?(group) || entities_changed?(group, entities)
            save_entities(group, entities)
            save_group_page_content(group, entities)
          end
          update_expiry(group)
        end
      end

      def update_expiry(group)
        @redis.expire(pages_key(group), EXPIRY_IN_SECONDS)
        @redis.expire(entities_key(group), EXPIRY_IN_SECONDS)
      end

      def entities_exists?(group)
        @redis.exists(entities_key(group)) && @redis.exists(pages_key(group))
      end

      # pre: @redis.get(entities_key(group)) != nil
      def entities_changed?(group, entities)
        stored_entities = JSON.parse(@redis.get(entities_key(group)))
        hash_changed?(entities, stored_entities) != []
      end

      def hash_changed?(entities, stored_entities)
        HashDiff.diff(stored_entities, entities)
      end

      def save_group_page_content(group, entities)
        key = pages_key(group)
        page = render(:group,
                      DiscoveryService::Renderer::Model::Group.new(entities))
        logger.info("Storing (k,v): ('#{key}','#{page}')")
        @redis.set(key, page)
      end

      def save_entities(group, entities)
        key = entities_key(group)
        value = entities.to_json
        logger.info("Storing (k,v): ('#{key}','#{value}')")
        @redis.set(key, value)
      end

      def pages_key(group)
        "pages:group:#{group}"
      end

      def entities_key(group)
        "entities:#{group}"
      end
    end
  end
end
