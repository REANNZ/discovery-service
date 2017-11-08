# frozen_string_literal: true

require 'active_support/core_ext/hash'
require 'active_support/core_ext/object/deep_dup'

module DiscoveryService
  module Renderer
    module Helpers
      # Helpers to render group page
      module Group
        attr_accessor :tag_groups

        def can_hide?(tag_group)
          not_first(tag_group) && not_last(tag_group) && not_all_tag(tag_group)
        end

        def all_tag?(tag_group)
          tag_group[:tag] == '*'
        end

        private

        def not_first(tag_group)
          tag_group != @tag_groups.first
        end

        def not_last(tag_group)
          tag_group != @tag_groups.last
        end

        def not_all_tag(tag_group)
          !all_tag?(tag_group)
        end
      end
    end
  end
end
