# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require_relative './init.rb'
require 'discovery_service'

run DiscoveryService::Application
