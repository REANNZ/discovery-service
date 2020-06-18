# frozen_string_literal: true

RSpec.describe DiscoveryService::Metadata::SAMLServiceClient do
  describe '#retrieve_entity_data(url)' do
    include_context 'build_entity_data'
    let(:logger) { spy }

    let(:klass) do
      Class.new do
        attr_accessor :logger

        include DiscoveryService::Metadata::SAMLServiceClient
        def initialize(logger)
          @logger = logger
        end
      end
    end

    let(:url) { 'http://saml-service.example.com/entities' }

    before do
      stub_request(:get, url).to_return(response)
    end

    subject { klass.new(logger).retrieve_entity_data(url) }

    context 'with a valid response ' do
      let(:response_body) do
        {
          entities: [
            build_idp_data(%w[discovery idp aaf vho]),
            build_sp_data(%w[aaf sp])
          ]
        }
      end

      let(:response) do
        { status: 200, body: JSON.generate(response_body) }
      end

      it 'disables https' do
        expect_any_instance_of(Net::HTTP).to receive(:use_ssl=).with(false)
        subject
      end

      it 'unmarshalls the payload to json as expected' do
        expect(subject).to eq(response_body)
      end

      context 'with an https url' do
        let(:url) { 'https://saml-service.example.com/entities' }

        it 'uses https' do
          expect_any_instance_of(Net::HTTP)
            .to receive(:use_ssl=).with(true).and_call_original
          subject
        end

        it 'unmarshalls the payload to json as expected' do
          expect(subject).to eq(response_body)
        end
      end
    end

    context 'with an invalid (400) response' do
      def run
        klass.new(logger).retrieve_entity_data(url)
      end

      let(:response) do
        { status: 400, body: JSON.generate([]) }
      end

      it 'propagates the exception' do
        expect { run }.to raise_error(Net::HTTPServerException)
        expect(logger).to have_received(:error)
      end
    end
  end
end
