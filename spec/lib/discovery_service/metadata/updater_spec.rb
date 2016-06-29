RSpec.describe DiscoveryService::Metadata::Updater do
  describe '#update' do
    let(:logger) { spy }
    let(:url) { 'http://saml-service.example.com/entities' }
    let(:redis) { Redis::Namespace.new(:discovery_service, redis: Redis.new) }
    let(:config) do
      { saml_service: { url: url },
        groups: { aaf:
                      { filters: [%w(discovery aaf)],
                        tag_groups:
                              [{ name: 'Australia', tag: 'aaf' },
                               { name: 'New Zealand', tag: 'tuakiri' }] },
                  edugain:
                      { filters: [%w(discovery edugain)],
                        tag_groups:
                                  [{ name: 'International', tag: '*' },
                                   { name: 'Australia', tag: 'aaf' },
                                   { name: 'New Zealand', tag: 'tuakiri' }] },
                  tuakiri:
                      { filters: [%w(discovery tuakiri)],
                        tag_groups:  false } },
        environment: { name: Faker::Lorem.word, status: Faker::Internet.url } }
    end

    before do
      allow(Logger).to receive(:new).and_return(logger)
      allow(YAML).to receive(:load_file).and_return(config)
      stub_request(:get, url).to_return(response)
    end

    def run
      DiscoveryService::Metadata::Updater.new.update
    end

    context 'with valid saml service response' do
      let(:expiry) { 28.days.to_i }
      include_context 'build_entity_data'

      context 'that is empty' do
        let(:response_body) { {} }

        let(:response) { { status: 200, body: JSON.generate(response_body) } }

        it 'stores entity and page key value pairs' do
          run
          expect(redis.keys.to_set)
            .to eq(['entities:aaf', 'entities:edugain', 'entities:tuakiri',
                    'pages:group:edugain', 'pages:group:aaf',
                    'pages:group:tuakiri'].to_set)
        end

        it 'stores each entity as an empty hash' do
          run
          expect(redis.get('entities:aaf')).to eq({}.to_json)
          expect(redis.get('entities:edugain')).to eq({}.to_json)
        end

        it 'stores an empty page for each configured tag' do
          run
          expect(redis.get('pages:group:aaf'))
            .to include('No organisations to select')
          expect(redis.get('pages:group:edugain'))
            .to include('No organisations to select')
          expect(redis.get('pages:group:tuakiri'))
            .to include('No organisations to select')
        end
      end

      context 'that contains no identity or service providers' do
        let(:response_body) do
          { identity_providers: [], service_providers: [] }
        end

        let(:response) { { status: 200, body: JSON.generate(response_body) } }

        it 'stores entity and page key value pairs' do
          run
          expect(redis.keys.to_set)
            .to eq(['entities:aaf', 'entities:edugain', 'entities:tuakiri',
                    'pages:group:edugain', 'pages:group:aaf',
                    'pages:group:tuakiri'].to_set)
        end

        it 'stores each entity as an empty hash' do
          run
          expect(redis.get('entities:aaf')).to eq({}.to_json)
          expect(redis.get('entities:edugain')).to eq({}.to_json)
        end

        it 'stores an empty page for each configured tag' do
          run
          expect(redis.get('pages:group:aaf'))
            .to include('No organisations to select')
          expect(redis.get('pages:group:edugain'))
            .to include('No organisations to select')
          expect(redis.get('pages:group:tuakiri'))
            .to include('No organisations to select')
        end
      end

      context 'that contains identity and service providers' do
        def result(entities)
          to_hash(entities).to_json
        end

        def add_tag(entity, tag)
          entity_copy = Marshal.load(Marshal.dump(entity))
          entity_copy[:tags] << tag
          entity_copy
        end

        context 'nothing stored in redis' do
          let(:aaf_idp) do
            build_idp_data(%w(discovery aaf vho), 'en')
          end

          let(:edugain_sp) do
            build_sp_data(%w(discovery edugain), 'en')
          end
          let(:non_matching_tuakiri_idp) do
            build_idp_data(%w(discovery tuakiri vho))
          end

          let(:response_body) do
            { identity_providers: [aaf_idp, non_matching_tuakiri_idp],
              service_providers: [edugain_sp] }
          end

          let(:response) { { status: 200, body: JSON.generate(response_body) } }

          it 'stores all entities and page content' do
            run
            expect(redis.keys.to_set)
              .to eq(['entities:aaf', 'entities:edugain', 'entities:tuakiri',
                      'pages:group:edugain', 'pages:group:aaf',
                      'pages:group:tuakiri'].to_set)
          end

          it 'sets an expiry for all entities' do
            Timecop.freeze do
              run
              expect(redis.ttl('entities:aaf')).to(equal(expiry))
              expect(redis.ttl('entities:edugain')).to(equal(expiry))
            end
          end

          let(:aaf_idp_tagged) { add_tag(aaf_idp, 'idp') }
          let(:edugain_sp_tagged) { add_tag(edugain_sp, 'sp') }

          it 'stores each matching entity as a key value pair' do
            run
            expect(redis.get('entities:aaf'))
              .to eq(result([aaf_idp_tagged]))
            expect(redis.get('entities:edugain'))
              .to eq(result([edugain_sp_tagged]))
          end

          it 'stores page content containing aaf idp' do
            run
            expect(redis.get('pages:group:aaf'))
              .to include(CGI.escapeHTML(aaf_idp[:names].first[:value]))
          end
        end

        context 'entities already stored in redis' do
          let(:original_ttl) { 10 }
          let(:aaf_idp) { build_idp_data(%w(discovery aaf), 'en') }

          let(:edugain_idp) do
            build_idp_data(%w(discovery edugain vho), 'en')
          end

          let(:unchanged_tuakiri_idp) do
            build_idp_data(%w(discovery tuakiri vho), 'en')
          end

          let(:aaf_idp_tagged) { add_tag(aaf_idp, 'idp') }
          let(:edugain_idp_tagged) { add_tag(edugain_idp, 'idp') }
          let(:tuakiri_idp_tagged) { add_tag(unchanged_tuakiri_idp, 'idp') }

          let(:aaf_entities) { result([aaf_idp_tagged]) }
          let(:aaf_page_content) { 'Original AAF page content here' }
          let(:edugain_entities) { result([edugain_idp_tagged]) }
          let(:edugain_page_content) { 'Original Edugain page content here' }
          let(:unchanged_tuakiri_entities) { result([tuakiri_idp_tagged]) }
          let(:tuakiri_page_content) { 'Original Tuakiri page content here' }
          let(:unconfigured_entities) { {}.to_json }
          let(:unconfigured_page_content) do
            'Unconfigured group page content here'
          end

          before do
            redis.set('entities:aaf', aaf_entities)
            redis.set('pages:group:aaf', aaf_page_content)
            redis.set('entities:edugain', edugain_entities)
            redis.set('pages:group:edugain', edugain_page_content)
            redis.set('entities:tuakiri', unchanged_tuakiri_entities)
            redis.set('pages:group:tuakiri', tuakiri_page_content)
            redis.set('entities:unconfigured', unconfigured_entities)
            redis.set('pages:group:unconfigured',
                      unconfigured_page_content)
          end

          let(:new_aaf_idp) do
            build_idp_data(%w(discovery aaf vho), 'en')
          end

          let(:response_body) do
            { identity_providers: [new_aaf_idp, aaf_idp, unchanged_tuakiri_idp],
              service_providers: [] }
          end

          let(:response) { { status: 200, body: JSON.generate(response_body) } }

          let(:new_aaf_idp_tagged) { add_tag(new_aaf_idp, 'idp') }

          it 'only stores matching entities from the latest response' do
            run
            expect(redis.get('entities:aaf'))
              .to eq(result([new_aaf_idp_tagged, aaf_idp_tagged]))
            expect(redis.get('entities:tuakiri'))
              .to eq(result([tuakiri_idp_tagged]))
          end

          it 'only stores matching page content from the latest response' do
            run
            expect(redis.get('pages:group:aaf'))
              .to include(CGI.escapeHTML(aaf_idp[:names].first[:value]))
            expect(redis.get('pages:group:aaf'))
              .to include(CGI.escapeHTML(new_aaf_idp[:names].first[:value]))
          end

          it 'generates new page content even if the entities are unchanged' do
            run
            expect(redis.get('pages:group:tuakiri'))
              .to include(CGI.escapeHTML(
                            unchanged_tuakiri_idp[:names].first[:value]
              ))
          end

          it 'only updates the ttl for entities contained in the response' do
            Timecop.freeze do
              redis.expire('entities:aaf', original_ttl)
              redis.expire('pages:group:aaf', original_ttl)
              redis.expire('entities:edugain', original_ttl)
              redis.expire('pages:group:edugain', original_ttl)
              redis.expire('entities:tuakiri', original_ttl)
              redis.expire('pages:group:tuakiri', original_ttl)

              redis.expire('entities:unconfigured', original_ttl)
              redis.expire('pages:group:unconfigured', original_ttl)

              run

              expect(redis.ttl('entities:aaf')).to(equal(expiry))
              expect(redis.ttl('pages:group:aaf')).to(equal(expiry))
              expect(redis.ttl('entities:tuakiri')).to(equal(expiry))
              expect(redis.ttl('pages:group:tuakiri')).to(equal(expiry))
              expect(redis.ttl('entities:edugain')).to(equal(expiry))
              expect(redis.ttl('pages:group:edugain')).to(equal(expiry))

              expect(redis.ttl('entities:unconfigured')).to(equal(original_ttl))
              expect(redis.ttl('pages:group:unconfigured'))
                .to(equal(original_ttl))
            end
          end
        end
      end
    end

    context 'with invalid (400) saml service response' do
      let(:response) { { status: 400, body: JSON.generate([]) } }

      it 'propagates the exception' do
        expect { run }.to raise_error(Net::HTTPServerException)
        expect(logger).to have_received(:error)
      end
    end
  end
end
