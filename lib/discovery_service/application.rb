require 'discovery_service/persistence/entity_cache'
require 'discovery_service/cookie/store'
require 'discovery_service/response/handler'
require 'discovery_service/entity/builder'
require 'discovery_service/validation/request_validations'
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

module DiscoveryService
  # Web application to allow users to select their IdP
  class Application < Sinatra::Base
    include DiscoveryService::Cookie::Store
    include DiscoveryService::Entity::Builder
    include DiscoveryService::Response::Handler
    include DiscoveryService::Validation::RequestValidations

    TEST_CONFIG = 'spec/feature/config/discovery_service.yml'
    CONFIG = 'config/discovery_service.yml'

    set :assets_precompile,
        %w(application.js application.css *.eot *.woff *.woff2 *.ttf)
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

    get '/discovery' do
      @idps = []
      idp_selections(request).each do |idp_selection|
        group = idp_selection[0]
        entity_id = idp_selection[1]
        next unless valid_group_name?(group) && group_configured?(group) &&
                    url?(entity_id) && @entity_cache.entities_exist?(group)
        entity = @entity_cache.entities_as_hash(group)[entity_id]
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

    get '/discovery/:group' do
      group = params[:group]
      return 400 unless valid_group_name?(group)
      saved_user_idp = idp_selections(request)[group]
      if url?(saved_user_idp) && url?(params[:entityID])
        params[:user_idp] = saved_user_idp
        handle_response(params)
      elsif group_exists?(group)
        @entity_cache.group_page(group)
      else
        status 404
      end
    end

    post '/discovery/:group' do
      return 400 unless valid_params?

      if params[:remember]
        save_idp_selection(params[:group], params[:user_idp], request, response)
      end

      idp_selection = idp_selections(request)[params[:group]]
      params[:user_idp] = idp_selection if idp_selection

      if passive?(params) && idp_selection.nil?
        redirect to(params[:return])
      else
        handle_response(params)
      end
    end
  end
end
