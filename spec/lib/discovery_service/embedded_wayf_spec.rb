# frozen_string_literal: true

RSpec.describe DiscoveryService::EmbeddedWAYF do
  let(:klass) do
    Class.new do
      include DiscoveryService::EmbeddedWAYF

      def initialize(entity_cache)
        @entity_cache = entity_cache
      end
    end
  end

  let(:entity_cache) do
    double(DiscoveryService::Persistence::EntityCache,
           entities_as_hash: entities_as_hash)
  end

  subject { klass.new(entity_cache) }

  describe '#embedded_wayf_javascript' do
    let(:output) { subject.embedded_wayf_javascript }
    let(:rendered_json) { /var idp_entities = (\[.*?\]);/m.match(output)[1] }
    let(:rendered_entities) { JSON.parse(rendered_json, symbolize_names: true) }

    let(:expected_entities) do
      [
        {
          entity_id: 'http://test1.example.edu/idp/shibboleth',
          name: 'Example IdP 1'
        },
        {
          entity_id: 'http://test2.example.edu/idp/shibboleth',
          name: 'Example IdP 2'
        }
      ]
    end

    let(:tagged_entities) do
      expected_entities.map { |e| e.merge(tags: %w[idp]) }
    end

    let(:entities_as_hash) do
      tagged_entities.reduce({}) do |a, e|
        attrs = {
          names: [
            { value: 'wrong', lang: 'fr' },
            { value: e[:name], lang: 'en' }
          ],
          tags: e[:tags]
        }
        a.merge(e[:entity_id] => attrs)
      end
    end

    it 'begins with a preamble' do
      expect(output)
        .to include('The AAF Embedded WAYF is deprecated and will be removed')
    end

    it 'renders a javascript IIFE' do
      expect(output).to match(%r{/\*.+\*/.*\(function\(\) \{.*\}\)\(\);$}m)
    end

    it 'includes the entities' do
      expect(rendered_entities).to eq(expected_entities)
    end

    context 'with a missing name' do
      let(:entities_as_hash) do
        tagged_entities.reduce({}) do |a, e|
          attrs = {
            names: [
              { value: 'wrong', lang: 'fr' }
            ],
            tags: e[:tags]
          }
          a.merge(e[:entity_id] => attrs)
        end
      end

      it 'uses the entity id as the name' do
        expect(rendered_entities)
          .to eq(expected_entities.map { |e| e.merge(name: e[:entity_id]) })
      end
    end

    context 'with an SP' do
      let(:extra_entities) do
        [
          {
            entity_id: 'http://sp.example.edu/shibboleth',
            name: 'Example SP which should be excluded'
          }
        ]
      end

      let(:tagged_entities) do
        [
          *expected_entities.map { |e| e.merge(tags: %w[idp aaf]) },
          *extra_entities.map { |e| e.merge(tags: %w[sp aaf]) }
        ]
      end

      it 'excludes the SP entity' do
        expect(rendered_entities.map { |e| e[:entity_id] })
          .not_to include(extra_entities[0][:entity_id])
      end
    end
  end
end
