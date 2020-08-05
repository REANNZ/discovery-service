# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'active_support/core_ext/object/deep_dup'

module DiscoveryService
  module Renderer
    module Controller
      # Generates group model based on requested language
      module Group
        include DiscoveryService::Entity::Builder

        def generate_group_model(entities, lang, tag_groups)
          result = { idps: [], sps: [] }
          tag_set = Set.new
          entities.nil? || entities.each_with_object(result) do |entity, hash|
            entity_types = entity_types_from_tags(entity)
            next if entity_types.empty?

            entity_types.each { |et| generate_entity_model(entity, hash, tag_set, lang, et) }
          end

          build_model(result, tag_groups, tag_set)
        end

        private

        def generate_entity_model(entity, hash, tag_set, lang, entity_type)
          entry = build_entry(entity, lang, entity_type)
          hash[entity_type] << entry
          tag_set.merge(entry[:tags])
        end

        def entity_types_from_tags(entity)
          entity_types = []
          entity_types.push(:sps) if entity[:tags].include?('sp')
          entity_types.push(:idps) if entity[:tags].include?('idp')
          entity_types
        end

        def build_model(result, tag_groups, tag_set)
          filtered_tag_groups = filter_tag_groups(tag_groups, tag_set)
          sorted_idps = result[:idps].sort_by { |idp| idp[:name].downcase }
          DiscoveryService::Renderer::Model::Group.new(sorted_idps,
                                                       result[:sps],
                                                       filtered_tag_groups)
        end

        def filter_tag_groups(tag_groups, tag_set)
          if tag_groups
            tag_groups.select do |tag_group|
              tag_set.include?(tag_group[:tag])
            end
          else
            []
          end
        end
      end
    end
  end
end
