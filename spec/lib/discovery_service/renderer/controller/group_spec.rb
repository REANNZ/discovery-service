RSpec.describe DiscoveryService::Renderer::Controller::Group do
  describe '#generate_group_model(entities, lang)' do
    include_context 'build_entity_data'

    let(:klass) do
      Class.new { include DiscoveryService::Renderer::Controller::Group }
    end

    let(:tag_group_1) do
      { name: Faker::Address.country, tag: Faker::Lorem.characters(10) }
    end

    let(:tag_group_2) do
      { name: Faker::Address.country, tag: Faker::Lorem.characters(10) }
    end

    let(:tag_groups) { [tag_group_1, tag_group_2] }
    let(:lang) { Faker::Lorem.characters(2) }

    def run
      klass.new.generate_group_model(entities, lang, tag_groups)
    end

    subject { run }

    context 'with nil entities' do
      let(:entities) { nil }
      it { is_expected.to_not be_nil }

      context 'generated idps' do
        subject { run.idps }
        it { is_expected.to eq([]) }
      end

      context 'generated sps' do
        subject { run.sps }
        it { is_expected.to eq([]) }
      end

      context 'the tag groups' do
        subject { run.tag_groups }
        it { is_expected.to eq([]) }

        context 'including a \'*\' tab' do
          let(:all_tag_group) { { name: 'International', tag: '*' } }
          let(:tag_groups) { [tag_group_1, tag_group_2, all_tag_group] }
          subject { run.tag_groups }
          it 'still includes the \'*\' group' do
            expect(subject).to eq([all_tag_group])
          end
        end
      end
    end

    context 'with no entities belonging in tag group' do
      let(:idp) { build_idp_data(['idp']) }
      let(:sp) { build_sp_data(['sp']) }
      let(:entities) { [idp, sp] }
      context 'the tag groups' do
        subject { run.tag_groups }
        it { is_expected.to eq([]) }
        context 'including a \'*\' tab' do
          let(:all_tag_group) { { name: 'International', tag: '*' } }
          let(:tag_groups) { [tag_group_1, tag_group_2, all_tag_group] }
          subject { run.tag_groups }
          it 'still includes the \'*\' group' do
            expect(subject).to eq([all_tag_group])
          end
        end
      end
    end

    context 'with entities belonging in a tag group' do
      let(:idp) { build_idp_data(['idp', tag_group_1[:tag]]) }
      let(:sp) { build_idp_data(['sp', tag_group_1[:tag]]) }
      let(:entities) { [idp, sp] }
      context 'the tag groups' do
        subject { run.tag_groups }
        it 'get filtered' do
          expect(subject).to eq([tag_group_1])
        end
      end
    end

    context 'with multiple entities belonging in multiple tag groups' do
      let(:idp1) { build_idp_data(['idp', tag_group_1[:tag]]) }
      let(:idp2) { build_idp_data(['idp', tag_group_2[:tag]]) }
      let(:sp1) { build_idp_data(['sp', tag_group_1[:tag]]) }
      let(:sp2) { build_idp_data(['sp', tag_group_2[:tag]]) }
      let(:entities) { [idp1, sp1, idp2, sp2] }
      context 'the tag groups' do
        subject { run.tag_groups }
        it 'get filtered' do
          expect(subject).to eq([tag_group_1, tag_group_2])
        end
      end
    end

    context 'with empty entities' do
      let(:entities) { [] }
      it { is_expected.to_not be_nil }

      context 'generated idps' do
        subject { run.idps }
        it { is_expected.to eq([]) }
      end

      context 'generated sps' do
        subject { run.sps }
        it { is_expected.to eq([]) }
      end
    end

    context 'with entities containing only mandatory fields' do
      let(:idp) do
        { entity_id: Faker::Internet.url, tags: ['idp', Faker::Lorem.word] }
      end
      let(:sp) do
        { entity_id: Faker::Internet.url, tags: ['sp', Faker::Lorem.word] }
      end
      let(:entities) { [idp, sp] }

      it { is_expected.to_not be_nil }

      context 'generated idps' do
        subject { run.idps }
        it 'builds idp as expected' do
          expect(subject).to eq([{ entity_id: idp[:entity_id],
                                   tags: idp[:tags],
                                   name: idp[:entity_id] }])
        end
      end

      context 'generated sps' do
        subject { run.sps }
        it 'builds sp as expected' do
          expect(subject).to eq([{ entity_id: sp[:entity_id],
                                   tags: sp[:tags],
                                   name: sp[:entity_id] }])
        end
      end
    end

    context 'with entities without names' do
      let(:idp_without_names) { build_idp_data(['idp'], lang).except(:names) }
      let(:sp_without_names) { build_sp_data(['sp'], lang).except(:names) }
      let(:entities) { [idp_without_names, sp_without_names] }

      it { is_expected.to_not be_nil }

      context 'generated idps' do
        subject { run.idps }
        it 'builds idp with entity id as name' do
          expect(subject.first[:name]).to eq(idp_without_names[:entity_id])
        end
      end

      context 'generated sps' do
        subject { run.sps }
        it 'builds sp with entity id as name' do
          expect(subject.first[:name]).to eq(sp_without_names[:entity_id])
        end
      end
    end

    context 'with one idp and one sp' do
      let(:idp) { build_idp_data(['idp'], lang) }
      let(:sp) { build_sp_data(['sp'], lang) }

      let(:entities) { [idp, sp] }

      it { is_expected.to_not be_nil }

      context 'generated idps' do
        subject { run.idps }
        it 'builds idp as expected' do
          expect(subject).to eq([{ entity_id: idp[:entity_id],
                                   tags: idp[:tags],
                                   name: CGI.escapeHTML(
                                     idp[:names].first[:value]
                                   ),
                                   logo_url: idp[:logos].first[:url],
                                   geolocations: idp[:geolocations] }])
        end
      end

      context 'generated sps' do
        subject { run.sps }
        it 'builds sp as expected' do
          expect(subject)
            .to eq([{ entity_id: sp[:entity_id],
                      tags: sp[:tags],
                      name: CGI.escapeHTML(
                        sp[:names].first[:value]
                      ),
                      logo_url: sp[:logos].first[:url],
                      description: CGI.escapeHTML(
                        sp[:descriptions].first[:value]
                      ),
                      information_url: sp[:information_urls].first[:url],
                      privacy_statement_url:
                        sp[:privacy_statement_urls].first[:url] }])
        end
      end
    end

    context 'multiple idps and sps' do
      let(:idp1) { build_idp_data(['idp'], lang, 'AAA University') }
      let(:idp2) { build_idp_data(['idp'], lang, 'BBB University') }
      let(:sp1) { build_sp_data(['sp'], lang) }
      let(:sp2) { build_sp_data(['sp'], lang) }

      let(:entities) { [idp1, sp1, idp2, sp2] }

      it { is_expected.to_not be_nil }

      context 'generated idps' do
        subject { run.idps }
        it 'builds and sorts idps as expected' do
          expect(subject)
            .to eq([{ entity_id: idp1[:entity_id],
                      tags: idp1[:tags],
                      name: CGI.escapeHTML(idp1[:names].first[:value]),
                      logo_url: idp1[:logos].first[:url],
                      geolocations: idp1[:geolocations] },
                    { entity_id: idp2[:entity_id],
                      tags: idp2[:tags],
                      name: CGI.escapeHTML(idp2[:names].first[:value]),
                      logo_url: idp2[:logos].first[:url],
                      geolocations: idp2[:geolocations] }])
        end
      end

      context 'generated sps' do
        subject { run.sps }
        it 'builds sps as expected' do
          expect(subject)
            .to eq([{ entity_id: sp1[:entity_id],
                      tags: sp1[:tags],
                      name: CGI.escapeHTML(sp1[:names].first[:value]),
                      logo_url: sp1[:logos].first[:url],
                      description: CGI.escapeHTML(
                        sp1[:descriptions].first[:value]
                      ),
                      information_url: sp1[:information_urls].first[:url],
                      privacy_statement_url:
                          sp1[:privacy_statement_urls].first[:url] },
                    { entity_id: sp2[:entity_id],
                      tags: sp2[:tags],
                      name: CGI.escapeHTML(sp2[:names].first[:value]),
                      logo_url: sp2[:logos].first[:url],
                      description: CGI.escapeHTML(
                        sp2[:descriptions].first[:value]
                      ),
                      information_url: sp2[:information_urls].first[:url],
                      privacy_statement_url:
                          sp2[:privacy_statement_urls].first[:url] }])
        end
      end
    end

    context 'with multiple idps of different languages' do
      let(:lang) { Faker::Lorem.characters(4) }
      let(:idp) { build_idp_data(['idp']) }
      let(:idp_with_matching_lang) { build_idp_data(['idp'], lang, 'ZZZ Uni') }

      let(:entities) { [idp, idp_with_matching_lang] }

      it { is_expected.to_not be_nil }

      context 'generated idps' do
        subject { run.idps }
        it 'builds and sorts idps as expected' do
          expect(subject)
            .to eq([{ entity_id: idp[:entity_id],
                      tags: idp[:tags],
                      name: idp[:entity_id],
                      geolocations: idp[:geolocations] },
                    { entity_id: idp_with_matching_lang[:entity_id],
                      tags: idp_with_matching_lang[:tags],
                      name: CGI.escapeHTML(
                        idp_with_matching_lang[:names].first[:value]
                      ),
                      logo_url: idp_with_matching_lang[:logos].first[:url],
                      geolocations: idp_with_matching_lang[:geolocations] }])
        end
      end
      context 'generated sps' do
        subject { run.sps }
        it { is_expected.to eq([]) }
      end
    end

    context 'with fields requiring escaping' do
      let(:idp) do
        { entity_id: '<onerror=\"javascript:alert(\'Oh, hello there!\')\"/>',
          tags: ['\'', 'idp'],
          names: [{ value: '&', lang: lang }],
          logos: [{ url: '"', lang: lang }],
          geolocations: [{ longitude: '>', latitude: '<' }] }
      end
      let(:sp) do
        { entity_id: '<body onload=\"javascript:alert(\'Oh, bye.\')\"/>',
          tags: ['&', 'sp'],
          names: [{ value: '\'', lang: lang }],
          information_urls: [{ url: '—', lang: lang }],
          privacy_statement_urls: [{ url: '&', lang: lang }],
          logos: [{ url: '\'', lang: lang }],
          descriptions: [{ value: '>', lang: lang }],
          discovery_response: ['<http:.[[±>'] }
      end

      let(:entities) { [idp, sp] }

      it { is_expected.to_not be_nil }

      context 'generated idps' do
        subject { run.idps }
        it 'builds idp with all fields escaped' do
          expect(subject)
            .to eq([{ entity_id: CGI.escapeHTML(idp[:entity_id]),
                      tags: idp[:tags].map { |t| CGI.escapeHTML(t) },
                      name: CGI.escapeHTML(idp[:names].first[:value]),
                      logo_url: CGI.escapeHTML(idp[:logos].first[:url]),
                      geolocations:
                           [{ longitude: CGI.escapeHTML(
                             idp[:geolocations].first[:longitude]
                           ),
                              latitude: CGI.escapeHTML(
                                idp[:geolocations].first[:latitude]
                              ) }] }])
        end
      end

      context 'generated sps' do
        subject { run.sps }
        it 'builds sp with all fields escaped' do
          expect(subject)
            .to eq([{ entity_id: CGI.escapeHTML(sp[:entity_id]),
                      tags: sp[:tags].map { |t| CGI.escapeHTML(t) },
                      name: CGI.escapeHTML(
                        sp[:names].first[:value]
                      ),
                      logo_url: CGI.escapeHTML(sp[:logos].first[:url]),
                      description: CGI.escapeHTML(
                        sp[:descriptions].first[:value]
                      ),
                      information_url:
                             CGI.escapeHTML(sp[:information_urls].first[:url]),
                      privacy_statement_url:
                             CGI.escapeHTML(
                               sp[:privacy_statement_urls].first[:url]
                             ) }])
        end
      end
    end
  end
end
