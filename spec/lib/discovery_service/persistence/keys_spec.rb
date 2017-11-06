# frozen_string_literal: true

RSpec.describe DiscoveryService::Persistence::Keys do
  let(:klass) { Class.new { include DiscoveryService::Persistence::Keys } }
  let(:group_name) { "#{Faker::Lorem.word}_#{Faker::Number.number(2)}-" }

  describe '#group_page_key(group)' do
    subject { klass.new.group_page_key(group_name) }
    it 'builds the page key' do
      expect(subject).to eq("pages:group:#{group_name}")
    end
  end

  describe '#entities_key(group)' do
    subject { klass.new.entities_key(group_name) }
    it 'builds the entities key' do
      expect(subject).to eq("entities:#{group_name}")
    end
  end
end
