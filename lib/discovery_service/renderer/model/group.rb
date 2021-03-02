# frozen_string_literal: true

module DiscoveryService
  module Renderer
    module Model
      # Model for the group page
      class Group
        attr_accessor :idps, :sps, :tag_groups

        include DiscoveryService::Renderer::Helpers::Group

        def initialize(idps, sps, tag_groups)
          @idps = idps
          @sps = sps
          @tag_groups = tag_groups
        end
      end
    end
  end
end
