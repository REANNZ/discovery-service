# frozen_string_literal: true

require 'aws-sdk'
require 'English'
require 'openssl'

module DiscoveryService
  # Consigns events to Amazon SQS for delivery to other services.
  class EventConsignment
    def initialize
      @sqs_config = DiscoveryService.configuration[:sqs]
      @identifier = SecureRandom.urlsafe_base64

      configure_fake_sqs if @sqs_config[:fake]
    end

    def perform
      in_progress do
        each_event_slice do |events|
          claims = { 'iss' => 'discovery-service', 'events' => events }
          jwe = JSON::JWT.new(claims).sign(key, :RS256).encrypt(key)
          sqs_client.send_message(queue_url: queue_url, message_body: jwe.to_s)
          redis.del(temporary_queue_key)
        end
      end
    end

    private

    def in_progress
      redis.sadd(in_progress_key, @identifier)
      yield
      redis.srem(in_progress_key, @identifier)
    end

    def each_event_slice
      queued_events.each_slice(10) do |events|
        begin
          yield events
        rescue
          requeue_events
          raise
        end
      end
    end

    def requeue_events
      nil while redis.rpoplpush(temporary_queue_key, queue_key)
      redis.srem(in_progress_key, @identifier)
    end

    def queued_events
      Enumerator.new do |y|
        while (event = redis.rpoplpush(queue_key, temporary_queue_key))
          y << JSON.parse(event)
        end
      end
    end

    def queue_url
      @sqs_config[:queue_url]
    end

    def sqs_client
      @sqs_client ||= Aws::SQS::Client.new(endpoint: @sqs_config[:endpoint],
                                           region: @sqs_config[:region])
    end

    def redis
      @redis ||= Redis::Namespace.new(:discovery_service, redis: Redis.new)
    end

    def key
      @key ||= OpenSSL::PKey::RSA.new(File.read(@sqs_config[:encryption_key]))
    end

    def configure_fake_sqs
      Aws::SQS::Client.remove_plugin(Aws::Plugins::SQSQueueUrls)

      queue_name = queue_url.split('/').last
      sqs_client.create_queue(queue_name: queue_name)
    end

    def queue_key
      'audit'
    end

    def temporary_queue_key
      "audit:#{@identifier}"
    end

    def in_progress_key
      'audit:in_progress'
    end
  end
end
