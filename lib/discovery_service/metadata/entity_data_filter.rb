# frozen_string_literal: true

module DiscoveryService
  module Metadata
    # Filters entity data based on tag config
    module EntityDataFilter
      def filter(entity_data, tag_config)
        tag_config.reduce({}) do |hash, (group, tag_config_for_group)|
          entities = entity_data.select do |entity|
            contains_tags?(entity, tag_config_for_group)
          end
          hash.merge(group => entities)
        end
      end

      def contains_tags?(entity, tag_config_for_group)
        tag_config_for_group.any? do |tags|
          entity[:tags].to_set.superset?(tags.to_set)
        end
      end
    end
  end
end
