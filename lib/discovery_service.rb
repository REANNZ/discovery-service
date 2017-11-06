# frozen_string_literal: true

require 'yaml'

require 'discovery_service/persistence'
require 'discovery_service/cookie'
require 'discovery_service/response'
require 'discovery_service/entity'
require 'discovery_service/validation'
require 'discovery_service/auditing'
require 'discovery_service/embedded_wayf'
require 'discovery_service/application'
require 'discovery_service/renderer'
require 'discovery_service/metadata'
require 'discovery_service/event_consignment'

# Top-level module for the Discovery Service project.
module DiscoveryService
  CONFIG_FILE = 'config/discovery_service.yml'

  class <<self
    attr_reader :configuration
  end

  @configuration = YAML.load_file(CONFIG_FILE)
end
