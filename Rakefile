require_relative 'init'
require 'sinatra/asset_pipeline/task'

begin
  require 'rspec/core/rake_task'
  require 'rubocop/rake_task'

  RSpec::Core::RakeTask.new(:spec)
  RuboCop::RakeTask.new

  task default: %i[spec rubocop]
rescue LoadError
  task default: []
end

require 'discovery_service'

Sinatra::AssetPipeline::Task.define! DiscoveryService::Application
