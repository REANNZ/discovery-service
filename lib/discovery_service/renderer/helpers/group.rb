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
          not_first(tag_group) && not_last(tag_group)
        end

        private

        def not_first(tag_group)
          tag_group != @tag_groups.first
        end

        def not_last(tag_group)
          tag_group != @tag_groups.last
        end
      end
    end
  end
end
