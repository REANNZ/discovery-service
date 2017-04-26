RSpec.describe DiscoveryService::Metadata::EntityDataFilter do
  describe '#filter(entity_data, tag_config)' do
    include_context 'build_entity_data'

    let(:logger) { spy }

    let(:klass) do
      Class.new do
        attr_accessor :logger
        include DiscoveryService::Metadata::EntityDataFilter
        def initialize(logger)
          @logger = logger
        end
      end
    end

    subject { klass.new(logger).filter(entity_data, tag_config) }

    context 'with empty arguments' do
      let(:entity_data) { {} }
      let(:tag_config) { {} }

      it 'returns empty hash' do
        expect(subject).to eq({})
      end
    end

    context 'with an empty tag config' do
      let(:entity_data) { build_idp_data(%w[discovery idp aaf vho]) }
      let(:tag_config) { {} }

      it 'filters everything out' do
        expect(subject).to eq({})
      end
    end

    context 'with one tag configured' do
      let(:tag_config) { { aaf: [%w[discovery aaf]] } }
      context 'and one matching entity' do
        let(:matching_entity) { build_idp_data(%w[discovery idp aaf vho]) }
        let(:entity_data) { [matching_entity] }
        it 'returns the matching entity' do
          expect(subject).to eq(aaf: [matching_entity])
        end
      end

      context 'and one matching entity amongst many' do
        let(:matching_entity) { build_idp_data(%w[discovery idp aaf vho]) }
        let(:other_entity) { build_idp_data(%w[random idp aaf vho]) }
        let(:entity_data) { [matching_entity, other_entity] }

        it 'returns the matching entity only' do
          expect(subject).to eq(aaf: [matching_entity])
        end
      end

      context 'and no matching entities amongst many' do
        let(:first_entity) { build_idp_data(%w[discovery idp tuakiri vho]) }
        let(:second_entity) { build_idp_data(%w[random idp tuakiri vho]) }
        let(:entity_data) { [first_entity, second_entity] }

        it 'returns a hash with empty entities' do
          expect(subject).to eq(aaf: [])
        end
      end

      context 'and multiple matching entities' do
        let(:first_match)  { build_idp_data(%w[discovery idp aaf vho]) }
        let(:second_match) { build_idp_data(%w[discovery idp aaf vho]) }
        let(:other_entity) { build_idp_data(%w[discovery idp tuakiri vho]) }
        let(:entity_data) do
          [first_match, second_match, other_entity]
        end

        it 'returns all matching entities' do
          expect(subject).to eq(aaf: [first_match, second_match])
        end
      end
    end

    context 'with multiple tags configured' do
      let(:tag_config) do
        {
          aaf: [%w[discovery aaf]],
          edugain: [%w[discovery aaf], %w[discovery edugain]]
        }
      end
      context 'and one matching entity' do
        let(:matching_entity) do
          build_idp_data(%w[discovery idp edugain vho])
        end
        let(:entity_data) { [matching_entity] }
        it 'returns the matching entity' do
          expect(subject).to eq(edugain: [matching_entity], aaf: [])
        end
      end

      context 'and one matching entity amongst many' do
        let(:matching_entity) { build_idp_data(%w[discovery idp aaf vho]) }
        let(:other_entity) { build_idp_data(%w[random idp aaf vho]) }
        let(:entity_data) { [matching_entity, other_entity] }

        it 'returns the matching entity only' do
          expect(subject).to eq(aaf: [matching_entity],
                                edugain: [matching_entity])
        end
      end

      context 'and no matching entities amongst many' do
        let(:first_entity) { build_idp_data(%w[discovery idp tuakiri vho]) }
        let(:second_entity) { build_idp_data(%w[random idp aaf vho]) }
        let(:entity_data) { [first_entity, second_entity] }

        it 'returns a hash with empty entities' do
          expect(subject).to eq(aaf: [], edugain: [])
        end
      end

      context 'and multiple matching entities' do
        let(:first_match) { build_idp_data(%w[discovery idp aaf vho]) }
        let(:second_match) { build_idp_data(%w[discovery idp aaf vho]) }
        let(:third_match) { build_idp_data(%w[discovery idp edugain vho]) }
        let(:other_entity) { build_idp_data(%w[discovery idp tuakiri vho]) }
        let(:entity_data) do
          [first_match, second_match, third_match, other_entity]
        end

        it 'returns all matching entities' do
          expect(subject).to eq(aaf: [first_match, second_match],
                                edugain: [first_match, second_match,
                                          third_match])
        end
      end
    end
  end
end
