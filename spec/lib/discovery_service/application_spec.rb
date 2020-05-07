# frozen_string_literal: true

RSpec.describe DiscoveryService::Application do
  include Rack::Test::Methods
  include_context 'build_entity_data'

  def actual_params
    Rack::Utils.parse_nested_query(URI.parse(last_response.location).query)
  end

  def actual_location
    last_response.location.split('?').first
  end

  def expect_matching_response(expected_location, expected_params)
    expect(actual_location).to eq(expected_location)
    expect(actual_params).to eq(expected_params)
  end

  def date_in_3_months
    (Time.now + 3.months).in_time_zone('UTC')
                         .strftime('%a, %d %b %Y %H:%M:%S GMT')
  end

  let(:redis) { Redis::Namespace.new(:discovery_service, redis: Redis.new) }
  let(:app) { DiscoveryService::Application.new }
  let(:environment_name) { Faker::Lorem.word }
  let(:environment_status_url) { Faker::Internet.url }

  let(:config) do
    { groups: {}, environment:
        { name: environment_name, status_url: environment_status_url } }
  end

  before do
    allow(DiscoveryService).to receive(:configuration).and_return(config)
  end

  def configure_group
    config[:groups][group_name.to_sym] = []
  end

  describe 'GET /' do
    let(:path) { '/' }
    def run
      get path
    end

    it 'responds with status code 302' do
      run
      expect(last_response.status).to eq(302)
    end

    it 'redirects to /discovery' do
      run
      expect(last_response.location).to eq('http://example.org/discovery')
    end
  end

  describe 'GET /health' do
    def run
      get '/health'
    end

    it 'responds with status code 200' do
      run
      expect(last_response.status).to eq(200)
    end
  end

  describe 'GET /embedded_wayf' do
    let(:group_name) { 'aaf' }

    before do
      configure_group
      redis.set('entities:aaf', '{}')
    end

    def run
      get '/embedded_wayf'
    end

    it 'responds with a javascript document' do
      run
      expect(last_response.status).to eq(200)
      expect(last_response['Content-Type'])
        .to start_with('application/javascript')
      expect(last_response.body).to include('AAF Embedded WAYF')
    end
  end

  describe 'GET /discovery' do
    let(:path) { '/discovery' }
    let(:existing_entity) { build_idp_data(['idp', group_name], 'en') }
    let(:group_name) do
      "#{Faker::Lorem.word}_#{Faker::Number.number(digits: 2)}-"
    end

    def run
      get path
    end

    context 'with no idps previously selected' do
      it 'shows that there are no organisations selected' do
        run
        expect(last_response.body)
          .to include('You have no saved organisations')
      end

      it 'shows the environment name' do
        run
        expect(last_response.body).to include(environment_name)
      end
    end

    context 'with idps previously selected' do
      context 'and the idp\'s group is gone' do
        let(:entity_id) { Faker::Internet.url }
        it 'shows that there are no organisations selected' do
          configure_group
          rack_mock_session.cookie_jar['selected_organisations'] =
            JSON.generate('other_group' => entity_id)
          run
          expect(last_response.body)
            .to include('You have no saved organisations')
        end
      end

      context 'and the idp does not exist anymore' do
        let(:entity_exists) { build_idp_data(['idp', group_name], 'en') }
        let(:entity_id) { Faker::Internet.url }
        it 'shows that there are no organisations selected' do
          configure_group
          redis.set("entities:#{group_name}",
                    to_hash([existing_entity]).to_json)
          rack_mock_session.cookie_jar['selected_organisations'] =
            JSON.generate(group_name => entity_id)
          run
          expect(last_response.body)
            .to include('You have no saved organisations')
        end
      end

      context 'and the idp and group do exist' do
        before do
          configure_group
          redis.set("entities:#{group_name}",
                    to_hash([existing_entity]).to_json)
          rack_mock_session.cookie_jar['selected_organisations'] =
            JSON.generate(group_name => existing_entity[:entity_id])
          run
        end

        it 'shows the idp name' do
          expect(last_response.body)
            .to include(CGI.escapeHTML(existing_entity[:names].first[:value]))
        end

        it 'contains a form to reset idps' do
          expect(last_response.body).to include('<form action="" '\
            'method="POST">')
        end

        it 'shows the help text header (singular)' do
          expect(last_response.body).to include('Your saved organisation')
        end

        it 'shows the help text body (singular)' do
          expect(last_response.body).to include('When you access a service, '\
          'you will be automatically sent to this organisation to log in.')
        end

        it 'shows the reset button' do
          expect(last_response.body).to include('Reset')
        end

        context 'with a name that requires escaping' do
          let(:lang) { 'en' }
          let(:existing_entity) do
            build_idp_data(['idp', group_name], lang).merge(
              names: [{ value: 'James\'s IdP', lang: lang }]
            )
          end

          it 'gets escaped' do
            expect(last_response.body)
              .to include(CGI.escapeHTML(
                            existing_entity[:names].first[:value]
                          ))
          end
        end
      end

      context 'and multiple idp selections exist' do
        let(:other_group_name) do
          "#{Faker::Lorem.word}_#{Faker::Number.number(digits: 3)}-"
        end

        let(:existing_entity) { build_idp_data(['idp', group_name], 'en') }
        let(:other_entity) do
          build_idp_data(['idp', other_group_name], 'en')
        end

        before do
          configure_group
          config[:groups][other_group_name.to_sym] = []
          redis.set("entities:#{group_name}",
                    to_hash([existing_entity]).to_json)
          redis.set("entities:#{other_group_name}",
                    to_hash([other_entity]).to_json)
          rack_mock_session.cookie_jar['selected_organisations'] =
            JSON.generate(group_name => existing_entity[:entity_id],
                          other_group_name => other_entity[:entity_id])
          run
        end

        it 'shows the idp names' do
          expect(last_response.body)
            .to include(CGI.escapeHTML(
                          existing_entity[:names].first[:value]
                        ))
          expect(last_response.body)
            .to include(CGI.escapeHTML(other_entity[:names].first[:value]))
        end

        it 'shows the help text header (plural)' do
          expect(last_response.body).to include('Your saved organisations')
        end

        it 'shows the help text body (plural)' do
          expect(last_response.body).to include('When you access a service, '\
          'you will be automatically sent to one of these organisations to'\
          ' log in.')
        end
      end

      context 'and the idp and group do exist but non \'en\' language' do
        let(:existing_entity) { build_idp_data(['idp', group_name]) }

        before do
          configure_group
          redis.set("entities:#{group_name}",
                    to_hash([existing_entity]).to_json)
          rack_mock_session.cookie_jar['selected_organisations'] =
            JSON.generate(group_name => existing_entity[:entity_id])
          run
        end

        it 'shows the organisation (entity id)' do
          expect(last_response.body)
            .to include(CGI.escapeHTML(existing_entity[:entity_id]))
        end

        it 'does not show the idp logo' do
          expect(last_response.body)
            .to_not include(existing_entity[:logos].first[:url])
        end
      end
    end
  end

  describe 'POST /discovery' do
    let(:group_name) do
      "#{Faker::Lorem.word}_#{Faker::Number.number(digits: 2)}-"
    end
    let(:originally_selected_idp) { Faker::Internet.url }

    let(:reset_cookie) do
      'selected_organisations=; path=/; max-age=0; '\
      'expires=Thu, 01 Jan 1970 00:00:00 GMT'
    end

    def run
      post '/discovery'
    end

    context 'when no idp selections are set' do
      it 'returns a status 200' do
        run
        expect(last_response.status).to eq(200)
      end

      it 'resets the idp selection cookies' do
        run
        expect(last_response['Set-Cookie']).to eq(reset_cookie)
      end

      it 'shows that there are no organisations selected' do
        run
        expect(last_response.body)
          .to include('You have no saved organisations')
      end

      it 'shows the environment name' do
        run
        expect(last_response.body).to include(environment_name)
      end
    end

    context 'when one idp selection is already set' do
      def set_cookie
        rack_mock_session.cookie_jar['selected_organisations'] =
          JSON.generate(group_name => originally_selected_idp)
      end

      it 'returns a status 200' do
        run
        expect(last_response.status).to eq(200)
      end

      it 'resets the idp selection cookies' do
        set_cookie
        run
        expect(last_response['Set-Cookie']).to eq(reset_cookie)
      end

      it 'shows that there are no organisations selected' do
        set_cookie
        run
        expect(last_response.body)
          .to include('You have no saved organisations')
      end
    end

    context 'when multiple idp selections are already set' do
      def set_cookie
        rack_mock_session.cookie_jar['selected_organisations'] =
          JSON.generate(group_name => originally_selected_idp,
                        other_group_name => other_selected_idp)
      end

      let(:other_group_name) do
        "#{Faker::Lorem.word}_#{Faker::Number.number(digits: 2)}-"
      end

      let(:other_selected_idp) { Faker::Internet.url }

      it 'returns a status 200' do
        run
        expect(last_response.status).to eq(200)
      end

      it 'resets the idp selection cookies' do
        set_cookie
        run
        expect(last_response['Set-Cookie']).to eq(reset_cookie)
      end

      it 'shows that there are no organisations selected' do
        set_cookie
        run
        expect(last_response.body)
          .to include('You have no saved organisations')
      end
    end
  end

  describe 'GET /discovery/:group' do
    let(:path_for_group) { "/discovery/#{group_name}?entityID=#{entity_id}" }
    let(:entity_id) { Faker::Internet.url }
    let(:group_name) { Faker::Lorem.word }

    def run
      get path_for_group
    end

    context 'with an non url-safe base64 alphabet group name' do
      let(:group_name) { '@*!' }

      it 'returns http status code 400' do
        run
        expect(last_response.status).to eq(400)
      end
    end

    context 'with a non-configured group' do
      it 'returns http status code 404' do
        run
        expect(last_response.status).to eq(404)
      end
    end

    context 'with a configured group and valid SP' do
      let(:id) { SecureRandom.urlsafe_base64 }
      let(:existing_sp) { build_sp_data(['sp', group_name]) }
      let(:entity_id) { existing_sp[:entity_id] }

      before do
        configure_group
        redis.set("entities:#{group_name}", to_hash([existing_sp]).to_json)
        expect(SecureRandom).to receive(:urlsafe_base64).and_return(id)
      end

      it 'redirects to a unique url with the query string' do
        run
        expect(last_response.status).to eq(302)
        uri = URI.parse(last_response.location)
        expect(uri.path).to match(%r{/discovery/#{group_name}/[a-zA-Z0-9_-]+})
        expect(CGI.unescape(uri.query)).to eq("entityID=#{entity_id}")
      end

      it 'stores the id in redis' do
        Timecop.freeze do
          run
          expect(redis.get("id:#{id}").to_s).to eq('1')
          expect(redis.ttl("id:#{id}")).to eq(3600)
        end
      end

      it 'writes an audit log entry' do
        expect { run }.to change { redis.llen('audit') }.by(1)
        json = redis.lindex('audit', 0)
        data = JSON.parse(json, symbolize_names: true)
        expect(data[:unique_id]).to eq(id)
      end
    end

    context 'with a configured group and valid SP and valid return url' do
      let(:id) { SecureRandom.urlsafe_base64 }
      let(:existing_sp) { build_sp_data(['sp', group_name]) }
      let(:entity_id) { existing_sp[:entity_id] }
      let(:return_url) { existing_sp[:discovery_response] }
      let(:path_for_group) do
        "/discovery/#{group_name}?entityID=#{entity_id}&return=#{return_url}"
      end

      before do
        configure_group
        redis.set("entities:#{group_name}", to_hash([existing_sp]).to_json)
        expect(SecureRandom).to receive(:urlsafe_base64).and_return(id)
      end

      it 'redirects to a unique url with the query string' do
        run
        expect(last_response.status).to eq(302)
        uri = URI.parse(last_response.location)
        expect(uri.path).to match(%r{/discovery/#{group_name}/[a-zA-Z0-9_-]+})
        expect(CGI.unescape(uri.query))
          .to eq("entityID=#{entity_id}&return=#{return_url}")
      end

      it 'stores the id in redis' do
        Timecop.freeze do
          run
          expect(redis.get("id:#{id}").to_s).to eq('1')
          expect(redis.ttl("id:#{id}")).to eq(3600)
        end
      end

      it 'writes an audit log entry' do
        expect { run }.to change { redis.llen('audit') }.by(1)
        json = redis.lindex('audit', 0)
        data = JSON.parse(json, symbolize_names: true)
        expect(data[:unique_id]).to eq(id)
      end
    end

    context 'with a configured group and unknown SP' do
      let(:id) { SecureRandom.urlsafe_base64 }

      before do
        configure_group
        # NOTE: leaving out test on SecureRandom.urlsafe_base64 calls because
        # these are called from the spec, not application code
      end

      it 'redirects to invalid_entity_id error url' do
        run
        expect(last_response.status).to eq(302)
        uri = URI.parse(last_response.location)
        expect(uri.path).to eq('/error/invalid_entity_id')
      end

      it 'does not store the id in redis' do
        Timecop.freeze do
          run
          expect(redis.get("id:#{id}").to_s).to eq('')
        end
      end

      it 'does not write an audit log entry' do
        expect { run }.to change { redis.llen('audit') }.by(0)
      end
    end

    context 'with a configured group and known SP with invalid return URL' do
      let(:id) { SecureRandom.urlsafe_base64 }
      let(:existing_sp) { build_sp_data(['sp', group_name]) }
      let(:entity_id) { existing_sp[:entity_id] }
      let(:return_url) { Faker::Internet.url }
      let(:path_for_group) do
        "/discovery/#{group_name}?entityID=#{entity_id}&return=#{return_url}"
      end

      before do
        configure_group
        redis.set("entities:#{group_name}", to_hash([existing_sp]).to_json)
        # NOTE: leaving out test on SecureRandom.urlsafe_base64 calls because
        # these are called from the spec, not application code
      end

      it 'redirects to invalid_entity_id error url' do
        run
        expect(last_response.status).to eq(302)
        uri = URI.parse(last_response.location)
        expect(uri.path).to eq('/error/invalid_return_url')
      end

      it 'does not store the id in redis' do
        Timecop.freeze do
          run
          expect(redis.get("id:#{id}").to_s).to eq('')
        end
      end

      it 'does not write an audit log entry' do
        expect { run }.to change { redis.llen('audit') }.by(0)
      end
    end

    context 'without an entityID' do
      let(:path_for_group) { "/discovery/#{group_name}" }

      before { configure_group }

      it 'returns http status code 400' do
        run
        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'GET /discovery/:group/:unique_id' do
    let(:entity_id) { Faker::Internet.url }
    let(:unique_id) { Faker::Lorem.words(number: 2).join('-') }
    let(:path_for_group) do
      "/discovery/#{group_name}/#{unique_id}?entityID=#{entity_id}"
    end

    def run
      get path_for_group
    end

    context 'with an non url-safe base64 alphabet group name' do
      before { run }
      let(:group_name) { '@*!' }
      it 'returns http status code 400' do
        expect(last_response.status).to eq(400)
      end
    end

    context 'with a url-safe base64 alphabet group name' do
      let(:page_content) { 'Page content here' }
      let(:group_name) do
        "#{Faker::Lorem.word}_#{Faker::Number.number(digits: 2)}-"
      end

      context 'when group exists in redis and config' do
        let(:config) { { groups: {} } }

        before do
          configure_group
          redis.set("pages:group:#{group_name}", page_content)
        end

        it 'returns http status code 200' do
          run
          expect(last_response.status).to eq(200)
        end

        it 'shows content' do
          run
          expect(last_response.body).to eq(page_content)
        end
      end

      context 'when group exists in redis but not config' do
        before { redis.set("pages:group:#{group_name}", page_content) }
        it 'returns http status code 404' do
          run
          expect(last_response.status).to eq(404)
        end
      end

      context 'when group exists in config but not redis' do
        before do
          config[:groups] = {}
          configure_group
        end

        it 'returns http status code 404' do
          run
          expect(last_response.status).to eq(404)
        end
      end

      context 'when group does not exist in redis or config' do
        it 'returns http status code 404' do
          run
          expect(last_response.status).to eq(404)
        end
      end

      context 'with the idp selection set but idp no longer exists' do
        let(:entity_id) { Faker::Internet.url }
        let(:page_content) { 'Page content here' }

        let(:path_for_group) do
          "/discovery/#{group_name}/#{unique_id}?entityID=#{entity_id}"
        end

        let(:encoded_cookie) do
          URI.encode_www_form_component(JSON.generate(reset_cookie))
        end

        context 'with cookie set for one group only' do
          let(:reset_cookie) do
            'selected_organisations=; path=/; max-age=0; '\
            'expires=Thu, 01 Jan 1970 00:00:00 GMT'
          end

          before do
            configure_group
            redis.set("entities:#{group_name}", '{}')
            redis.set("pages:group:#{group_name}", page_content)
            rack_mock_session.cookie_jar['selected_organisations'] =
              JSON.generate(group_name => entity_id)
            run
          end

          it 'returns http status code 200' do
            run
            expect(last_response.status).to eq(200)
          end

          it 'shows content' do
            run
            expect(last_response.body).to eq(page_content)
          end

          it 'resets the idp selection' do
            expect(last_response['Set-Cookie']).to eq(reset_cookie)
          end
        end

        context 'with cookie set for multiple groups' do
          let(:other_idp) { Faker::Internet.url }
          let(:other_group) do
            "#{Faker::Lorem.word}_#{Faker::Number.number(digits: 2)}-"
          end

          let(:multiple_idp_selections) do
            { other_group => other_idp }.merge(
              group_name => entity_id
            )
          end

          let(:expected_encoded_cookie) do
            URI.encode_www_form_component(
              JSON.generate(other_group => other_idp)
            )
          end

          def expected_cookie
            "selected_organisations=#{expected_encoded_cookie};"\
                " path=/; expires=#{date_in_3_months}"
          end

          def setup_and_run
            configure_group
            redis.set("entities:#{group_name}", '{}')
            redis.set("pages:group:#{group_name}", page_content)
            rack_mock_session.cookie_jar['selected_organisations'] =
              JSON.generate(multiple_idp_selections)
            run
          end

          it 'returns http status code 200' do
            setup_and_run
            expect(last_response.status).to eq(200)
          end

          it 'shows content' do
            setup_and_run
            expect(last_response.body).to eq(page_content)
          end

          it 'resets the idp selection for the current group only' do
            Timecop.freeze do
              setup_and_run
              expect(last_response['Set-Cookie']).to eq(expected_cookie)
            end
          end
        end
      end

      context 'with the idp selection set' do
        let(:entity) { build_idp_data(['idp', group_name]) }

        let(:path_for_group) do
          "/discovery/#{group_name}/#{unique_id}?entityID=#{entity_id}"
        end

        before do
          configure_group
          redis.set("entities:#{group_name}", to_hash([entity]).to_json)
          allow_any_instance_of(DiscoveryService::Application)
            .to receive(:handle_response).and_return('stubbed')
          rack_mock_session.cookie_jar['selected_organisations'] =
            JSON.generate(group_name => entity[:entity_id])
          run
        end

        it 'handles the response' do
          expect(last_response.body).to eq('stubbed')
        end

        it 'records an audit entry' do
          expect { run }.to change { redis.llen('audit') }.by(1)
          json = redis.lindex('audit', 0)
          data = JSON.parse(json, symbolize_names: true)
          expect(data).to include(unique_id: unique_id,
                                  selection_method: 'cookie')
        end
      end

      context 'with passive and return parameters' do
        let(:selected_idp) { build_idp_data(['idp', group_name]) }
        let(:existing_sp) { build_sp_data(['sp', group_name]) }
        let(:entity_id) { existing_sp[:entity_id] }
        let(:requesting_sp) { existing_sp[:entity_id] }
        let(:sp_return_url) do
          existing_sp[:all_discovery_response_endpoints].first
        end
        let(:selected_idp_entity_id) { selected_idp[:entity_id] }
        let(:passive) { 'true' }

        let(:path_for_group) do
          "/discovery/#{group_name}/#{unique_id}?entityID=#{entity_id}"\
          "&isPassive=#{passive}&return=#{sp_return_url}"
        end

        before do
          configure_group
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, selected_idp]).to_json)
        end

        context 'without cookies' do
          before do
            run
          end

          it 'returns http status code 302' do
            expect(last_response.status).to eq(302)
          end

          it 'redirects back to sp using return url and no entity id' do
            expect_matching_response(sp_return_url, {})
          end
        end

        context 'with cookies' do
          before do
            rack_mock_session.cookie_jar['selected_organisations'] =
              JSON.generate(group_name => selected_idp_entity_id)
            run
          end

          it 'returns http status code 302' do
            expect(last_response.status).to eq(302)
          end

          it 'redirects back to sp with entity id because'\
             ' idp is resolved from cookies' do
            expect_matching_response(sp_return_url,
                                     'entityID' => selected_idp_entity_id)
          end
        end
      end

      context 'with passive parameter but no return' do
        let(:selected_idp) { build_idp_data(['idp', group_name]) }
        let(:existing_sp) { build_sp_data_no_return(['sp', group_name]) }
        let(:entity_id) { existing_sp[:entity_id] }
        let(:selected_idp_entity_id) { selected_idp[:entity_id] }
        let(:passive) { 'true' }

        let(:path_for_group) do
          "/discovery/#{group_name}/#{unique_id}?entityID=#{entity_id}"\
          "&isPassive=#{passive}"
        end

        before do
          configure_group
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp]).to_json)
        end

        context 'without cookies' do
          before do
            run
          end

          it 'returns http status code 404 as no return found' do
            expect(last_response.status).to eq(404)
          end
        end

        context 'with cookies' do
          before do
            rack_mock_session.cookie_jar['selected_organisations'] =
              JSON.generate(group_name => selected_idp_entity_id)
            run
          end

          it 'returns http status code 404 as no return found' do
            expect(last_response.status).to eq(404)
          end
        end

        context 'with cookies and discovery response stored' do
          let(:existing_sp) { build_sp_data(['sp', group_name]) }
          before do
            rack_mock_session.cookie_jar['selected_organisations'] =
              JSON.generate(group_name => existing_sp[:entity_id])
            run
          end

          it 'returns http status code 302 as discovery response is used' do
            expect(last_response.status).to eq(302)
          end

          it 'redirects back to sp using discovery response value' do
            expect_matching_response(existing_sp[:discovery_response],
                                     'entityID' => existing_sp[:entity_id])
          end
        end
      end
    end
  end

  describe 'GET /api/discovery/:group' do
    let(:group_name) do
      "#{Faker::Lorem.word}_#{Faker::Number.number(digits: 2)}-"
    end

    def expected_idp(idp)
      { entity_id: idp[:entity_id],
        names: idp[:names],
        logos: idp[:logos],
        tags: idp[:tags],
        single_sign_on_endpoints: idp[:single_sign_on_endpoints] }
    end

    def run
      get "/api/discovery/#{group_name}"
    end

    context 'with group name invalid' do
      let(:group_name) { '*' }

      before do
        run
      end

      it 'returns http status code 400 (bad request)' do
        expect(last_response.status).to eq(400)
      end
    end

    context 'with group not existing' do
      before do
        run
      end

      it 'returns http status code 400 (bad request)' do
        expect(last_response.status).to eq(400)
      end
    end

    context 'with no entities existing for group' do
      before do
        configure_group
        redis.set("entities:#{group_name}", to_hash([]).to_json)
        run
      end

      it 'returns http status code 200' do
        expect(last_response.status).to eq(200)
      end

      it 'returns an empty list' do
        expect(last_response.body)
          .to eq(JSON.generate(identity_providers: []))
      end
    end

    context 'with one idp existing for group' do
      let(:idp) { build_idp_data(['idp', group_name]) }
      before do
        configure_group
        redis.set("entities:#{group_name}",
                  to_hash([idp]).to_json)
        run
      end

      it 'returns http status code 200' do
        expect(last_response.status).to eq(200)
      end

      it 'sets the content type to application/json' do
        expect(last_response.content_type)
          .to eq('application/json;charset=utf-8')
      end

      it 'returns the entity as expected' do
        expect(last_response.body)
          .to eq(JSON.generate(identity_providers: [expected_idp(idp)]))
      end
    end

    context 'with idp containing only mandatory fields' do
      let(:idp) { { entity_id: Faker::Internet.url, tags: ['idp'] } }

      before do
        configure_group
        redis.set("entities:#{group_name}",
                  to_hash([idp]).to_json)
        run
      end

      it 'returns the idp with no keys for empty fields' do
        expect(last_response.body)
          .to eq(JSON.generate(identity_providers: [
                                 { entity_id: idp[:entity_id],
                                   tags: [idp[:tags].first] }
                               ]))
      end
    end

    context 'with idp and sp existing for group' do
      let(:idp) { build_idp_data(['idp', group_name]) }
      let(:sp) { build_sp_data(['sp', group_name]) }
      before do
        configure_group
        redis.set("entities:#{group_name}",
                  to_hash([idp, sp]).to_json)
        run
      end

      it 'returns the idp as expected' do
        expect(last_response.body)
          .to eq(JSON.generate(identity_providers: [expected_idp(idp)]))
      end
    end

    context 'with many idps and sps existing for group' do
      let(:idp1) { build_idp_data(['idp', group_name]) }
      let(:idp2) { build_idp_data(['idp', group_name]) }
      let(:sp1) { build_sp_data(['sp', group_name]) }
      let(:sp2) { build_sp_data(['sp', group_name]) }
      before do
        configure_group
        redis.set("entities:#{group_name}",
                  to_hash([idp1, idp2, sp1, sp2]).to_json)
        run
      end

      it 'returns the idps as expected' do
        expect(last_response.body)
          .to eq(JSON.generate(identity_providers: [expected_idp(idp1),
                                                    expected_idp(idp2)]))
      end
    end
  end

  describe 'POST /discovery/:group/:unique_id' do
    let(:group_name) { Faker::Lorem.word }
    let(:existing_idp) { build_idp_data(['idp', group_name]) }
    let(:existing_sp) { build_sp_data(['sp', group_name]) }
    let(:selected_idp) { existing_idp[:entity_id] }
    let(:form_content) { { user_idp: selected_idp } }
    let(:requesting_sp) { existing_sp[:entity_id] }
    let(:sp_return_url) { existing_sp[:all_discovery_response_endpoints].first }
    let(:unique_id) { SecureRandom.urlsafe_base64 }
    let(:base_path) { "/discovery/#{group_name}/#{unique_id}" }

    def run
      post path, form_content
    end

    context 'when group is not configured' do
      before { run }
      let(:path) { "#{base_path}?entityID=#{requesting_sp}" }

      it 'returns http status code 404' do
        expect(last_response.status).to eq(404)
      end
    end

    context 'when group is configured' do
      before { configure_group }

      context 'without mandatory entity id parameter' do
        let(:path) { base_path.to_s }

        before { run }

        it 'returns http status code 400' do
          expect(last_response.status).to eq(400)
        end
      end

      context 'without mandatory user idp form field' do
        let(:path) { "#{base_path}?entityID=#{requesting_sp}" }
        let(:form_content) { {} }

        before { run }

        it 'returns http status code 400' do
          expect(last_response.status).to eq(400)
        end
      end

      context 'with an invalid (non url) idp selection (form field)' do
        let(:path) { "#{base_path}?entityID=#{requesting_sp}" }
        let(:form_content) { { user_idp: '!@#ASDJK~##@!' } }

        before { run }

        it 'returns http status code 400' do
          expect(last_response.status).to eq(400)
        end
      end

      context 'with invalid (non url) entity id' do
        let(:path) { "#{base_path}?entityID=!ASDASDJTK@" }

        before { run }

        it 'returns http status code 400' do
          expect(last_response.status).to eq(400)
        end
      end

      context 'with an non url-safe base64 alphabet group name' do
        let(:group_name) { '@*!' }
        let(:path) do
          "#{base_path}?entityID=#{requesting_sp}"
        end

        before { run }

        it 'returns http status code 400' do
          expect(last_response.status).to eq(400)
        end
      end

      context 'with unknown entity_id' do
        let(:path) { "#{base_path}?entityID=#{Faker::Internet.url}" }

        before do
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, existing_idp]).to_json)
          run
        end

        it 'returns http status code 302' do
          expect(last_response.status).to eq(302)
        end

        it 'shows error page for unknown entity' do
          expect_matching_response(
            'http://example.org/error/invalid_entity_id', {}
          )
        end
      end

      context 'with an entity id parameter, no return parameter and no'\
              ' discovery response stored' do
        let(:existing_sp) { build_sp_data_no_return(['sp', group_name]) }
        let(:path) { "#{base_path}?entityID=#{requesting_sp}" }

        before do
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, existing_idp]).to_json)
          run
        end

        it 'returns http status code 404' do
          expect(last_response.status).to eq(404)
        end
      end

      context 'with an entity id parameter, no return parameter but discovery'\
              ' response stored' do
        let(:requesting_sp) { existing_sp[:entity_id] }

        let(:path) { "#{base_path}?entityID=#{requesting_sp}" }

        before do
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, existing_idp]).to_json)
          run
        end

        it 'returns http status code 302' do
          expect(last_response.status).to eq(302)
        end

        it 'redirects back to sp using discovery response value' do
          expect_matching_response(existing_sp[:discovery_response],
                                   'entityID' => selected_idp)
        end
      end

      context 'with entity id and return parameter' do
        let(:path) do
          "#{base_path}?entityID=#{requesting_sp}"\
          "&return=#{sp_return_url}"
        end

        before do
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, existing_idp]).to_json)
          run
        end

        context 'without enforcing return url configured' do
          it 'returns http status code 302' do
            expect(last_response.status).to eq(302)
          end

          it 'redirects back to sp using return url value' do
            expect_matching_response(sp_return_url, 'entityID' => selected_idp)
          end
        end

        context 'ensure return url param is enforced per spec' do
          let(:config) do
            { groups: {}, environment:
              { name: environment_name, status_url: environment_status_url } }
          end

          context 'with valid return url provided' do
            it 'returns http status code 302' do
              expect(last_response.status).to eq(302)
            end

            it 'redirects back to sp using return url value' do
              expect_matching_response(sp_return_url,
                                       'entityID' => selected_idp)
            end
          end

          context 'with invalid return url provided' do
            let(:path) do
              "#{base_path}?entityID=#{requesting_sp}"\
                '&return=https://attacker.com'
            end

            it 'shows error page for invalid return_url' do
              expect(last_response.status).to eq(302)
              expect_matching_response(
                'http://example.org/error/invalid_return_url', {}
              )
            end
          end
        end
      end

      context 'with the option to remember organisation on' do
        let(:path) do
          "#{base_path}?entityID=#{requesting_sp}"\
          "&return=#{sp_return_url}"
        end

        def expected_cookie
          "selected_organisations=#{encoded_cookie};"\
                " path=/; expires=#{date_in_3_months}"
        end

        let(:form_content) { { user_idp: selected_idp, remember: 'on' } }
        let(:cookie_as_hash) { { group_name => selected_idp } }

        let(:encoded_cookie) do
          URI.encode_www_form_component(JSON.generate(cookie_as_hash))
        end

        context 'no idp selection previously' do
          before do
            redis.set("entities:#{group_name}",
                      to_hash([existing_sp, existing_idp]).to_json)
            run
          end
          it 'returns http status code 302' do
            expect(last_response.status).to eq(302)
          end

          it 'redirects back to sp using return url value' do
            expect_matching_response(sp_return_url, 'entityID' => selected_idp)
          end

          it 'sets a cookie for the selected idp' do
            Timecop.freeze do
              expect(last_response['Set-Cookie']).to eq(expected_cookie)
            end
          end
        end

        context 'with a idp selection already saved' do
          let(:originally_selected_idp) { Faker::Internet.url }

          it 'overwrites the cookie for the selected idp' do
            Timecop.freeze do
              redis.set("entities:#{group_name}",
                        to_hash([existing_sp, existing_idp]).to_json)
              rack_mock_session.cookie_jar['selected_organisations'] =
                JSON.generate(group_name => originally_selected_idp)
              run
              expect(last_response['Set-Cookie']).to eq(expected_cookie)
            end
          end
        end

        context 'with a idp selection already saved for another group' do
          let(:other_idp) { Faker::Internet.url }
          let(:other_group) do
            "#{Faker::Lorem.word}_#{Faker::Number.number(digits: 2)}-"
          end

          let(:other_selected_organisation_hash) do
            { other_group => other_idp }
          end

          let(:encoded_cookie) do
            URI.encode_www_form_component(
              JSON.generate(other_selected_organisation_hash.merge(
                              cookie_as_hash
                            ))
            )
          end

          it 'maintains the idp for the other group' do
            Timecop.freeze do
              redis.set("entities:#{group_name}",
                        to_hash([existing_sp, existing_idp]).to_json)
              rack_mock_session.cookie_jar['selected_organisations'] =
                JSON.generate(other_selected_organisation_hash)
              run
              expect(last_response['Set-Cookie']).to eq(expected_cookie)
            end
          end
        end
      end

      context 'with entity id and return parameter containing a query' do
        let(:return_query) { CGI.escape('?a=b&c=d') }
        let(:sp_return_url_with_query) { "#{sp_return_url}#{return_query}" }
        let(:path) do
          "#{base_path}?entityID=#{requesting_sp}"\
          "&return=#{sp_return_url_with_query}"
        end

        before do
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, existing_idp]).to_json)
          run
        end

        it 'returns http status code 302' do
          expect(last_response.status).to eq(302)
        end

        it 'redirects back to sp using return url value' do
          expect_matching_response(sp_return_url,
                                   'entityID' => selected_idp,
                                   'a' => 'b',
                                   'c' => 'd')
        end

        it 'records an audit entry' do
          json = redis.lindex('audit', 0)
          data = JSON.parse(json, symbolize_names: true)
          expect(data).to include(unique_id: unique_id,
                                  selection_method: 'manual')
        end
      end

      context 'with entity id, return and return id parameter' do
        let(:path) do
          "#{base_path}?entityID=#{requesting_sp}"\
          "&return=#{sp_return_url}&returnIDParam=myCustomEntityID"
        end

        before do
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, existing_idp]).to_json)
          run
        end

        it 'returns http status code 302' do
          expect(last_response.status).to eq(302)
        end

        it 'redirects back to sp using return url value and custom entity id' do
          expect_matching_response(sp_return_url,
                                   'myCustomEntityID' => selected_idp)
        end
      end

      context 'with entity id, return and policy parameter' do
        let(:path) do
          "#{base_path}?entityID=#{requesting_sp}"\
          "&return=#{sp_return_url}&policy=#{policy}"
        end

        before do
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, existing_idp]).to_json)
          run
        end

        context 'with unsupported policy' do
          let(:policy) { 'unsupported_policy ' }
          it 'returns http status code 400' do
            expect(last_response.status).to eq(400)
          end
        end

        context 'with supported policy' do
          let(:policy) do
            'urn:oasis:names:tc:SAML:profiles:SSO:idp-discovery-protocol:single'
          end

          it 'returns http status code 302' do
            expect(last_response.status).to eq(302)
          end

          it 'redirects back to sp using return url value' do
            expect_matching_response(sp_return_url, 'entityID' => selected_idp)
          end
        end
      end

      context 'with entity id parameter, return parameter and also a'\
              ' discovery response' do
        let(:path) do
          "#{base_path}?entityID=#{requesting_sp}&return=#{sp_return_url}"
        end

        before do
          redis.set("entities:#{group_name}",
                    to_hash([existing_sp, existing_idp]).to_json)
          run
        end

        it 'returns http status code 302' do
          expect(last_response.status).to eq(302)
        end

        it 'ignores stored discovery response value and uses return param' do
          expect_matching_response(sp_return_url, 'entityID' => selected_idp)
        end
      end

      context 'with a missing idp' do
        let(:path) do
          "#{base_path}?entityID=#{requesting_sp}&return=#{sp_return_url}"
        end

        before { run }

        it 'returns http status code 302 as idp is not found' do
          expect(last_response.status).to eq(302)
        end

        it 'redirects to /error/missing_idp as idp is not found' do
          expect(last_response.location)
            .to eq('http://example.org/error/missing_idp')
        end
      end
    end
  end

  describe 'GET /error/missing_idp' do
    def run
      get '/error/missing_idp'
    end

    before { run }

    it 'responds with status code 200' do
      expect(last_response.status).to eq(200)
    end

    it 'display missing idp message' do
      expect(last_response.body)
        .to include('We seem to have misplaced something')
    end
  end
end
