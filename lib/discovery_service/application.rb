require 'sinatra/base'
require 'json'

module DiscoveryService
  # Web application to allow users to select their IdP
  class Application < Sinatra::Base
    configure :development, :test do
      enable :logging
    end

    def initialize
      super
      @redis = Redis::Namespace.new(:discovery_service, redis: Redis.new)
    end

    get '/discovery/:group' do
      page = @redis.get("pages:index:#{params[:group]}")
      page ? page : (status 404)
    end
  end
end
