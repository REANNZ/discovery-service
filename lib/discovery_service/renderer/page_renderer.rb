# frozen_string_literal: true

module DiscoveryService
  module Renderer
    # Generates a page using Slim
    module PageRenderer
      include Sprockets::Helpers

      attr_accessor :environment

      def render(page, model, environment)
        @environment = environment
        layout = Slim::Template.new('views/layout.slim')
        content = Slim::Template.new("views/#{page}.slim")
                                .render(model)
        layout.render(self) { content }
      end
    end
  end
end
