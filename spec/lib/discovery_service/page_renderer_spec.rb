require 'discovery_service/page_renderer'
require 'discovery_service/group'

RSpec.describe DiscoveryService::PageRenderer do

  context '#render' do
    include_context 'build_entity_data'
    include_context 'stringify_keys'

    let(:klass) { Class.new { include DiscoveryService::PageRenderer } }

    let(:group_name) { Faker::Lorem.word }
    let(:entity_1) do
      stringify_keys(build_entity_data(['test', 'idp', group_name, 'vho']))
    end

    let(:entity_2) do
      stringify_keys(build_entity_data(['test', 'idp', group_name, 'vho']))
    end

    subject do
      klass.new.render(:index,
                       DiscoveryService::PageRenderer::Group.new(
                           [entity_1, entity_2]))
    end

    context 'the result' do
      it 'includes the layout' do
        expect(subject).to include('<!DOCTYPE html>')
        expect(subject).to include('</html>')
      end

      it 'includes the title' do
        expect(subject).to include('<title>AAF Discovery Service</title>')
      end

      it 'includes the selection string' do
        expect(subject).to include('Select your IdP:')
      end

      it 'includes the entities' do
        expect(subject).to include(Nokogiri::HTML(entity_1[:name]).text)
        expect(subject).to include(Nokogiri::HTML(entity_2[:name]).text)
      end
    end
  end
end
