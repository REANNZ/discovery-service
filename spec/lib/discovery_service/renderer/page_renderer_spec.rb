# frozen_string_literal: true

RSpec.describe DiscoveryService::Renderer::PageRenderer do
  describe '#render(page, model, environment)' do
    let(:klass) do
      Class.new { include DiscoveryService::Renderer::PageRenderer }
    end

    let(:environment) do
      { name: Faker::Lorem.word, status_url: Faker::Internet.url }
    end

    let(:tag1) { Faker::Address.country_code }
    let(:tag2) { Faker::Address.country_code }

    let(:tag_groups) do
      [{ name: Faker::Address.country, tag: :tag1 },
       { name: Faker::Address.country, tag: :tag2 },
       { name: Faker::Address.country, tag: '*' }]
    end

    let(:idps) { [] }
    let(:sps) { [] }

    subject do
      klass.new.render(:group,
                       DiscoveryService::Renderer::Model::Group.new(
                         idps, sps, tag_groups
                       ), environment)
    end

    it 'includes the layout' do
      expect(subject).to include('<!DOCTYPE html>')
      expect(subject).to include('</html>')
    end

    it 'includes the title' do
      expect(subject).to include('<title>Tuakiri Discovery Service</title>')
    end

    it 'shows that there are no idps' do
      expect(subject).to include('No organisations to select')
    end

    it 'includes the environment name' do
      expect(subject).to include(environment[:name].to_s)
    end

    context 'with idps' do
      let(:group_name) { Faker::Lorem.word }
      let(:select_button_class) { 'select_idp_button' }

      let(:idp_1) do
        { name: CGI.escapeHTML(Faker::University.name),
          entity_id: Faker::Internet.url,
          tags: %i[tag1 tag2] }
      end
      let(:idp_2) do
        { name: CGI.escapeHTML(Faker::University.name),
          entity_id: Faker::Internet.url,
          tags: %i[tag1 tag2] }
      end

      let(:idps) { [idp_1, idp_2] }

      let(:expected_open_form_tag) do
        '<form class="idp_selection_form" method="POST" tabindex="1">'
      end

      it 'includes the selection string' do
        expect(subject).to include('Search for your organisation')
      end

      it 'includes a form to submit idp selection' do
        expect(subject).to include(expected_open_form_tag)
      end

      it 'includes the organisations to select' do
        expect(subject).to include(idp_1[:name])
        expect(subject).to include(idp_2[:name])
      end

      it 'includes a submit button for each idp' do
        expect(subject).to include("<button class=\"#{select_button_class}\""\
          ' name="user_idp" tabindex="2" type="submit"'\
          " value=\"#{idp_1[:entity_id]}\">Select</button>")
        expect(subject).to include("<button class=\"#{select_button_class}\""\
          ' name="user_idp" tabindex="3" type="submit"'\
          " value=\"#{idp_2[:entity_id]}\">Select</button>")
      end

      it 'includes the main (javascript enabled) idp selection button' do
        expect(subject)
          .to include('<span class="continue_button button" disabled="">'\
                      'Continue to your organisation</span>')
      end

      it 'includes the organisations to select' do
        expect(subject).to include(idp_1[:name])
        expect(subject).to include(idp_2[:name])
      end

      context 'containing a name that has already been escaped' do
        let(:lang) { 'en' }

        let(:idp_1) do
          { name: 'James&#39;s IdP', entity_id: Faker::Internet.url,
            tags: [:tag1] }
        end

        it 'does not get escaped again' do
          expect(subject).to include(idp_1[:name])
        end
      end

      it 'includes the first tab' do
        expect(subject).to include('<li class="current tab" '\
          "data-tab=\"tag-#{tag_groups.first[:tag]}\">"\
          "#{CGI.escapeHTML(tag_groups.first[:name])}")
      end

      it 'includes the middle tabs (allowed to be hidden)' do
        ts = tag_groups - [tag_groups.first, tag_groups.last]
        ts.each do |t|
          expect(subject).to include('<li class=" tab" '\
            "data-tab=\"tag-#{t[:tag]}\">"\
            "#{CGI.escapeHTML(t[:name])}")
        end
      end

      it 'includes the last tab (configured as "*")' do
        t = tag_groups.find { |tag_group| tag_group[:tag] == '*' }
        expect(subject).to include('<li class=" tab" '\
          "data-tab=\"tag-#{t[:tag]}\">"\
          "#{CGI.escapeHTML(t[:name])}")
      end
    end
  end
end
