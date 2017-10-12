# frozen_string_literal: true

RSpec.describe DiscoveryService::Auditing do
  let(:klass) do
    Class.new do
      include DiscoveryService::Auditing
      attr_reader :redis

      def initialize(redis)
        @redis = redis
      end
    end
  end

  let(:redis) { Redis.new }
  subject { klass.new(redis) }

  let(:base_data) do
    {
      user_agent: Faker::Lorem.sentence,
      ip: Faker::Internet.ip_v4_address,
      initiating_sp: Faker::Internet.url,
      timestamp: Time.now.utc.xmlschema,
      group: Faker::Lorem.word
    }
  end

  let(:headers) do
    {
      'HTTP_USER_AGENT' => data[:user_agent],
      'HTTP_X_FORWARDED_FOR' => data[:ip],
      'REMOTE_ADDR' => data[:ip]
    }
  end

  let(:env) { Rack::MockRequest.env_for('/discovery/group', headers) }
  let(:request) { Rack::Request.new(env) }

  describe '#record_request' do
    let(:data) { base_data }
    let(:params) { { group: data[:group], entityID: data[:initiating_sp] } }

    def run
      subject.record_request(request, params)
    end

    it 'returns a unique identifier' do
      value = run
      expect(value).to be_a(String)
      expect(value).not_to eq(run)
    end

    it 'records the request' do
      value = nil
      expect { value = run }.to change { redis.llen('audit') }.by(1)
      json = redis.lindex('audit', 0)
      recorded = JSON.parse(json, symbolize_names: true)

      expect(recorded).to eq(data.merge(unique_id: value, phase: 'request'))
    end
  end

  describe '#record_manual_selection' do
    let(:unique_id) { SecureRandom.urlsafe_base64 }

    let(:data) do
      base_data.merge(
        selected_idp: Faker::Internet.url,
        selection_method: 'manual',
        unique_id: unique_id
      )
    end

    let(:params) do
      {
        group: data[:group],
        entityID: data[:initiating_sp],
        user_idp: data[:selected_idp]
      }
    end

    def run
      subject.record_manual_selection(request, params, unique_id)
    end

    it 'records the response' do
      expect { run }.to change { redis.llen('audit') }.by(1)
      json = redis.lindex('audit', 0)
      recorded = JSON.parse(json, symbolize_names: true)

      expect(recorded).to eq(data.merge(phase: 'response'))
    end
  end

  describe '#record_cookie_selection' do
    let(:unique_id) { SecureRandom.urlsafe_base64 }
    let(:idp) { Faker::Internet.url }

    let(:data) do
      base_data.merge(
        selected_idp: idp,
        selection_method: 'cookie',
        unique_id: unique_id
      )
    end

    let(:params) do
      {
        group: data[:group],
        entityID: data[:initiating_sp]
      }
    end

    def run
      subject.record_cookie_selection(request, params, unique_id, idp)
    end

    it 'records the response' do
      expect { run }.to change { redis.llen('audit') }.by(1)
      json = redis.lindex('audit', 0)
      recorded = JSON.parse(json, symbolize_names: true)

      expect(recorded).to eq(data.merge(phase: 'response'))
    end
  end
end
