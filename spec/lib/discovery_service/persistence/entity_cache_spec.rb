# frozen_string_literal: true

RSpec.describe DiscoveryService::Persistence::EntityCache do
  include_context 'build_entity_data'
  let(:redis) { Redis::Namespace.new(:discovery_service, redis: Redis.new) }
  let(:instance) { DiscoveryService::Persistence::EntityCache.new }
  let(:group) { Faker::Lorem.word }

  describe '#entities(group)' do
    subject { instance.entities(group) }
    context 'when entities do not exist for group' do
      it { is_expected.to be_nil }
    end

    context 'when entities exist for group' do
      let(:entity) { build_entity_data }
      let(:entities) { to_hash([entity]).to_json }
      before { redis.set("entities:#{group}", entities) }
      it 'returns the entities as json string' do
        expect(subject)
          .to eq("{\"#{entity[:entity_id]}\":{"\
              "\"names\":[{\"value\":\"#{entity[:names].first[:value]}\","\
                         "\"lang\":\"#{entity[:names].first[:lang]}\"}],"\
              "\"tags\":#{entity[:tags].to_json},"\
              "\"logos\":[{\"url\":\"#{entity[:logos].first[:url]}\","\
                         "\"lang\":\"#{entity[:logos].first[:lang]}\"}],"\
              "\"domains\":#{entity[:domains]}}}")
      end
    end
  end

  describe '#entities_as_hash(group)' do
    subject { instance.entities_as_hash(group) }
    context 'when entities do not exist for group' do
      it { is_expected.to be_nil }
    end

    context 'when entities exist for group' do
      let(:entity) { build_entity_data }
      let(:entities) { to_hash([entity]).to_json }
      before { redis.set("entities:#{group}", entities) }
      it 'returns the entities as hash with key as entity id' do
        expect(subject).to eq(to_hash([entity]))
      end
    end
  end

  describe '#entities_exist?(group)' do
    subject { instance.entities(group) }
    context 'when entities do not exist for group' do
      it { is_expected.to be_falsey }
    end

    context 'when entities exist for group' do
      let(:entity) { build_entity_data }
      let(:entities) { to_hash([entity]).to_json }
      before { redis.set("entities:#{group}", entities) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#save_entities(entities, group)' do
    let(:entity) { build_entity_data }

    subject { instance.save_entities([entity], group) }
    it { is_expected.to eq('OK') }

    context 'the stored entity' do
      before { instance.save_entities([entity], group) }
      subject { redis.get("entities:#{group}") }
      it 'is a json string' do
        expect(subject)
          .to eq("{\"#{entity[:entity_id]}\":{"\
              "\"names\":[{\"value\":\"#{entity[:names].first[:value]}\","\
                         "\"lang\":\"#{entity[:names].first[:lang]}\"}],"\
              "\"tags\":#{entity[:tags].to_json},"\
              "\"logos\":[{\"url\":\"#{entity[:logos].first[:url]}\","\
                         "\"lang\":\"#{entity[:logos].first[:lang]}\"}],"\
              "\"domains\":#{entity[:domains]}}}")
      end
    end
  end

  describe '#group_page(group)' do
    subject { instance.group_page(group) }
    context 'when group page does not exist for group' do
      it { is_expected.to be_nil }
    end

    context 'when group page exists for group' do
      before { redis.set("pages:group:#{group}", 'content') }
      it 'returns the raw content' do
        expect(subject).to eq('content')
      end
    end
  end

  describe '#group_page_exists?(group)' do
    subject { instance.group_page_exists?(group) }
    context 'when group page does not exist for group' do
      it { is_expected.to be_falsey }
    end

    context 'when group page exists for group' do
      before { redis.set("pages:group:#{group}", 'content') }
      it { is_expected.to be_truthy }
    end
  end

  describe '#save_group_page(group, page)' do
    let(:content) { 'group page content' }

    subject { instance.save_group_page(group, content) }
    it { is_expected.to eq('OK') }

    context 'the stored page' do
      before { instance.save_group_page(group, content) }
      subject { redis.get("pages:group:#{group}") }
      it { is_expected.to eq(content) }
    end
  end

  describe '#update_expiry(group)' do
    let(:original_ttl) { 10 }
    let(:expiry) { 28.days.to_i }
    let(:entity) { build_entity_data }
    let(:entities) { to_hash([entity]).to_json }
    let(:page_content) { 'page content here' }

    let(:page_key) { "pages:group:#{group}" }
    let(:entities_key) { "entities:#{group}" }

    before do
      redis.set(entities_key, entities)
      redis.set(page_key, page_content)
    end

    it 'updates expiry' do
      Timecop.freeze do
        redis.expire(entities_key, original_ttl)
        redis.expire(page_key, original_ttl)
      end

      instance.update_expiry(group)

      expect(redis.ttl(entities_key)).to(equal(expiry))
      expect(redis.ttl(page_key)).to(equal(expiry))
    end
  end

  describe '#entities_diff(group, entities)' do
    let(:entity) { build_entity_data }
    let(:entities_key) { "entities:#{group}" }
    let(:original_entities) { to_hash([entity]).to_json }
    before { redis.set(entities_key, original_entities) }

    let(:updated_names) do
      [{ value: "#{entity[:names].first[:value]} Version 2",
         lang: entity[:names].first[:lang] }]
    end

    let(:updated_entity) do
      {
        entity_id: entity[:entity_id],
        names: updated_names,
        tags: entity[:tags],
        logos: entity[:logos],
        domains: entity[:domains]
      }
    end

    let(:new_entity) { build_entity_data }
    let(:updated_entities) { [updated_entity, new_entity] }
    subject { instance.entities_diff(group, updated_entities) }

    it 'returns a diff of the updated and new entity' do
      expect(subject)
        .to eq([['-', "#{entity[:entity_id]}.names[0]",
                 { value: entity[:names].first[:value],
                   lang: entity[:names].first[:lang] }],
                ['+', "#{entity[:entity_id]}.names[0]",
                 { value: updated_entity[:names].first[:value],
                   lang: updated_entity[:names].first[:lang] }],
                ['+', new_entity[:entity_id],
                 { names: new_entity[:names],
                   tags: new_entity[:tags],
                   logos: new_entity[:logos],
                   domains: new_entity[:domains] }]])
    end
  end

  describe '#default_discovery_response(group, entity_id)' do
    context 'when entity does not exist' do
      subject do
        instance.default_discovery_response(group, Faker::Internet.url)
      end

      it { is_expected.to be_nil }
    end

    context 'when entity without discovery response exists' do
      let(:entity) do
        build_sp_data.except(:discovery_response)
      end
      let(:entities) { to_hash([entity]).to_json }
      before { redis.set("entities:#{group}", entities) }
      subject { instance.default_discovery_response(group, entity[:entity_id]) }

      it { is_expected.to be_nil }
    end

    context 'when entity with discovery response exists' do
      let(:entity) { build_sp_data }
      let(:entities) { to_hash([entity]).to_json }
      before { redis.set("entities:#{group}", entities) }
      subject { instance.default_discovery_response(group, entity[:entity_id]) }

      it 'should eq discovery response' do
        expect(subject).to eq(entity[:discovery_response])
      end
    end
  end

  describe '#all_discovery_response(group, entity_id)' do
    context 'when entity does not exist' do
      subject do
        instance.all_discovery_response(group, Faker::Internet.url)
      end

      it { is_expected.to be_nil }
    end

    context 'when entity without discovery response exists' do
      let(:entity) do
        build_sp_data.except(:discovery_response,
                             :all_discovery_response_endpoints)
      end
      let(:entities) { to_hash([entity]).to_json }

      before { redis.set("entities:#{group}", entities) }
      subject { instance.all_discovery_response(group, entity[:entity_id]) }

      it { is_expected.to be_nil }
    end
    context 'when entity with discovery response exists' do
      let(:entity) { build_sp_data }
      let(:entities) { to_hash([entity]).to_json }
      before { redis.set("entities:#{group}", entities) }
      subject { instance.all_discovery_response(group, entity[:entity_id]) }

      it 'should eq discovery response' do
        expect(subject).to eq(entity[:all_discovery_response_endpoints])
      end
    end
  end
end
