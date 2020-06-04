# frozen_string_literal: true

source 'https://rubygems.org'

gem 'god', require: false
gem 'sinatra', require: false
gem 'unicorn', require: false

gem 'aws-sdk', '~> 2', require: false

gem 'redis'
gem 'redis-namespace'
gem 'slim'

gem 'activesupport', '~> 5.2.4'
gem 'hashdiff'
gem 'json-jwt'
gem 'rack'

gem 'sinatra-asset-pipeline'
gem 'sprockets-helpers'

gem 'therubyracer', require: false
gem 'uglifier', require: false

source 'https://rails-assets.org' do
  gem 'rails-assets-jquery'
  gem 'rails-assets-jquery.scrollbar'
  gem 'rails-assets-mousetrap'
  gem 'rails-assets-picnic'
end

group :development, :test do
  gem 'faker'
  gem 'fakeredis'
  gem 'rack-test'
  gem 'rspec'
  gem 'timecop'
  gem 'webmock'

  gem 'capybara', require: false
  gem 'nokogiri', '>= 1.10'
  gem 'phantomjs', require: 'phantomjs/poltergeist'
  gem 'poltergeist', require: false

  gem 'i18n', '~> 0.7.0'
  gem 'pry', require: false

  gem 'codeclimate-test-reporter', require: false
  gem 'simplecov', require: false

  gem 'guard', require: false
  gem 'guard-bundler', require: false
  gem 'guard-rspec', require: false
  gem 'guard-rubocop', require: false
  gem 'guard-unicorn', require: false
  gem 'terminal-notifier-guard', require: false

  gem 'rubocop-faker', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false

  gem 'aaf-gumboot'
end
