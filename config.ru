# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require_relative './init.rb'
require 'discovery_service'

use Rack::Deflater
run DiscoveryService::Application
