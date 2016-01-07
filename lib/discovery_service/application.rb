require 'discovery_service/persistence/entity_cache'
require 'discovery_service/cookie/store'
require 'discovery_service/response/handler'
require 'discovery_service/response/api_response_builder'
require 'discovery_service/entity/builder'
require 'discovery_service/validation/request_validations'
require 'discovery_service/auditing'
require 'discovery_service/embedded_wayf'
require 'sinatra/base'
require 'sinatra/cookies'
require 'sinatra/asset_pipeline'
require 'rails-assets-jquery'
require 'rails-assets-semantic-ui'
require 'rails-assets-datatables'
require 'rails-assets-slimscroll'
require 'sprockets'
require 'sprockets-helpers'
require 'json'
require 'yaml'
require 'uri'

# rubocop:disable Metrics/ClassLength
# TODO: Reenable this cop

module DiscoveryService
  # Web application to allow users to select their IdP
  class Application < Sinatra::Base
    include DiscoveryService::Cookie::Store
    include DiscoveryService::Entity::Builder
    include DiscoveryService::Response::Handler
    include DiscoveryService::Response::APIResponseBuilder
    include DiscoveryService::Validation::RequestValidations
    include DiscoveryService::Auditing
    include DiscoveryService::EmbeddedWAYF

    attr_reader :redis

    TEST_CONFIG = 'spec/feature/config/discovery_service.yml'
    CONFIG = 'config/discovery_service.yml'

    set :assets_precompile,
        %w(application.js application.css style-rich.css style-basic.css
           *.eot *.woff *.woff2 *.ttf)
    set :assets_css_compressor, :sass
    set :assets_js_compressor, :uglifier

    register Sinatra::AssetPipeline

    RailsAssets.load_paths.each { |path| settings.sprockets.append_path(path) }
    settings.sprockets.append_path('assets/javascripts')
    settings.sprockets.append_path('assets/stylesheets')

    helpers Sprockets::Helpers

    set :root, File.expand_path('../..', File.dirname(__FILE__))
    set :group_config, CONFIG
    set :public_folder, 'public'

    configure :test do
      set :group_config, TEST_CONFIG
    end

    def initialize
      super
      @logger = Logger.new("log/#{settings.environment}.log")
      @entity_cache = DiscoveryService::Persistence::EntityCache.new
      cfg = YAML.load_file(settings.group_config)
      @groups = cfg[:groups]
      @environment = cfg[:environment]
      @logger.info('Initialised with group configuration: '\
        "#{JSON.pretty_generate(@groups)}")
      @redis = Redis::Namespace.new(:discovery_service, redis: Redis.new)
    end

    def group_configured?(group)
      @groups.key?(group.to_sym)
    end

    def group_exists?(group)
      group_configured?(group) && @entity_cache.group_page_exists?(group)
    end

    get '/' do
      redirect to('/discovery')
    end

    get '/health' do
      Redis.new.ping
      'ok'
    end

    get '/embedded_wayf' do
      content_type 'application/javascript'
      embedded_wayf_javascript
    end

    get '/discovery' do
      @idps = []
      idp_selections(request).each do |group, entity_id|
        next unless valid_group_name?(group) && group_configured?(group) &&
                    uri?(entity_id) && @entity_cache.entities_exist?(group)
        entities = @entity_cache.entities_as_hash(group)
        next unless entities.key?(entity_id)
        entity = entities[entity_id]
        entity[:entity_id] = entity_id
        entry = build_entry(entity, 'en', :idp)
        @idps << entry
      end
      slim :selected_idps
    end

    post '/discovery' do
      delete_idp_selection(response)
      slim :selected_idps
    end

    before %r{\A/discovery/([^/]+)(/.+)?\z} do |group, _|
      halt 400 unless valid_group_name?(group) && uri?(params[:entityID])
      halt 404 unless group_configured?(group)
    end

    get '/discovery/:group' do |group|
      id = record_request(request, params)
      @redis.set("id:#{id}", '1', ex: 3600)
      path = "/discovery/#{group}/#{id}"
      path += "?#{request.query_string}" if request.query_string != ''
      redirect to(path)
    end

    def entity_exists?(group, entity_id)
      entities = @entity_cache.entities_as_hash(group)
      entities && entities.key?(entity_id)
    end

    get '/discovery/:group/:unique_id' do |group, unique_id|
      saved_user_idp = idp_selections(request)[group]
      if saved_user_idp && !entity_exists?(group, saved_user_idp)
        remove_idp_selection(group, request, response)
        saved_user_idp = nil
      end

      if uri?(saved_user_idp) && uri?(params[:entityID])
        params[:user_idp] = saved_user_idp
        record_cookie_selection(request, params, unique_id, saved_user_idp)
        handle_response(params)
      elsif passive?(params) && params[:return]
        redirect to(params[:return])
      elsif group_exists?(group)
        @entity_cache.group_page(group)
      else
        status 404
      end
    end

    get '/api/discovery/:group' do |group|
      content_type 'application/json;charset=utf-8'
      return 400 unless valid_group_name?(group) && group_configured?(group)
      entities = @entity_cache.entities_as_hash(group)
      JSON.generate(build_api_response(entities))
    end

    post '/discovery/:group/:unique_id' do |group, unique_id|
      return 400 unless valid_params?
      unless entity_exists?(group, params[:user_idp])
        return redirect to('/error/missing_idp')
      end

      if params[:remember]
        save_idp_selection(group, params[:user_idp], request, response)
      end

      record_manual_selection(request, params, unique_id)
      handle_response(params)
    end

    get '/error/missing_idp' do
      slim :missing_idp
    end

    error 400 do
      slim :bad_request
    end

    error 404 do
      slim :not_found
    end
  end
end
