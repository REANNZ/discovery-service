require 'bundler/setup'
require 'simplecov'
require 'capybara/rspec'
require 'webmock/rspec'
require 'aws-sdk'

ENV['RACK_ENV'] = 'test'
Bundler.require(:test)
Dir['./spec/support/*.rb'].each { |f| require f }

require_relative '../init.rb'

require 'fakeredis/rspec'

require 'discovery_service'
Capybara.app = DiscoveryService::Application

I18n.config.enforce_available_locales = true
I18n.config.default_locale = :en

Aws.config.update(stub_responses: true)

DiscoveryService.instance_eval do
  @configuration = {
    saml_service: {
      url: 'http://localhost:8080/entities'
    },
    groups: {
      tuakiri: {
        filters: [
          %w[tuakiri other]
        ],
        tag_groups: false
      },
      aaf: {
        filters: [
          %w[discovery aaf],
          %w[sp aaf],
          %w[idp aaf],
          %w[tuakiri]
        ],
        tag_groups: [
          { name: 'Australia', tag: 'aaf' },
          { name: 'New Zealand', tag: 'tuakiri' }
        ]
      },
      edugain: {
        filters: [
          %w[discovery aaf],
          %w[discovery tuakiri],
          %w[discovery edugain]
        ],
        tag_groups: [
          { name: 'Australia', tag: 'aaf' },
          { name: 'New Zealand', tag: 'tuakiri' },
          { name: 'International', tag: '*' }
        ]
      }
    },
    environment: {
      name: 'Test Environment',
      status_url: 'http://status.test.aaf.edu.au'
    }
  }
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!

  RSpec::Matchers.define_negated_matcher :not_change, :change
end
