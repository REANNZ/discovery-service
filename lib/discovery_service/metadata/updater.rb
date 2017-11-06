# frozen_string_literal: true

require 'yaml'
require 'redis'
require 'redis-namespace'
require 'slim'
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
      include DiscoveryService::Renderer::Controller::Group

      def initialize
        @logger = Logger.new('log/updater.log')
        @entity_cache = DiscoveryService::Persistence::EntityCache.new
      end

      def update
        logger.info 'Update start'
        config = YAML.load_file('config/discovery_service.yml')
        raw_entities = retrieve_entity_data(config[:saml_service][:url])
        grouped_entities = filter(combine_sp_idp(raw_entities),
                                  group_config(config, :filters))
        save_entities(grouped_entities, group_config(config, :tag_groups),
                      config[:environment])
        logger.info 'Update complete'
      end

      private

      def group_config(config, key)
        config[:groups].reduce({}) do |hash, (group, group_cfg)|
          hash.merge(group => group_cfg[key])
        end
      end

      def save_entities(grouped_entities, tag_groups, environment)
        grouped_entities.each do |group, entities|
          if !@entity_cache.entities_exist?(group) || changed?(entities, group)
            save_entities_content(group, entities)
          end
          save_group_page_content(group, entities, tag_groups[group],
                                  environment)
          update_expiry(group)
        end
      end

      def combine_sp_idp(raw_entities)
        idps = raw_entities[:identity_providers]
        sps = raw_entities[:service_providers]
        [add_tag(idps, 'idp'), add_tag(sps, 'sp')].compact.reduce([], :+)
      end

      def add_tag(entities, tag)
        entities&.each { |e| e[:tags] << tag }
      end

      def update_expiry(group)
        logger.info("Extending expiry for group '#{group}'")
        @entity_cache.update_expiry(group)
      end

      def changed?(entities, group)
        diff = @entity_cache.entities_diff(group, entities)
        changed = diff.any?
        logger.info("Entity data changed for '#{group}': #{diff}") if changed
        changed
      end

      def save_group_page_content(group, entities, tag_groups, environment)
        page = render(:group, generate_group_model(entities, 'en',
                                                   tag_groups),
                      environment)
        logger.info("Rebuilt page for group '#{group}'")
        @entity_cache.save_group_page(group, page)
      end

      def save_entities_content(group, entities)
        logger.info("Storing entities for group '#{group}': '#{entities}'")
        @entity_cache.save_entities(entities, group)
      end
    end
  end
end
