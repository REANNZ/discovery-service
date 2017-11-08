#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../init.rb'
require 'discovery_service'

DiscoveryService::EventConsignment.new.perform
