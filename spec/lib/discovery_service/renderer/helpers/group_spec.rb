RSpec.describe DiscoveryService::Renderer::Helpers::Group do
  let(:klass) do
    Class.new { include DiscoveryService::Renderer::Helpers::Group }
  end

  let(:all_group) { { name: 'International', tag: '*' } }

  let(:tag_groups) do
    [{ name: Faker::Address.country, tag: Faker::Address.country_code },
     { name: Faker::Address.country, tag: Faker::Address.country_code },
     all_group]
  end

  let(:instance) do
    helper = klass.new
    helper.tag_groups = tag_groups
    helper
  end

  describe '#can_hide?' do
    context 'the first tag group' do
      subject { instance.can_hide?(tag_groups.first) }
      it 'can not be hidden' do
        expect(subject).to be_falsey
      end
    end

    context 'the all group' do
      subject { instance.can_hide?(all_group) }
      it 'can never be hidden' do
        expect(subject).to be_falsey
      end
    end

    context 'the last tag group' do
      subject { instance.can_hide?(tag_groups.last) }
      it 'can not be hidden' do
        expect(subject).to be_falsey
      end
    end

    context 'the other tag groups' do
      let(:other_tag_groups) do
        tag_groups - [tag_groups.first, tag_groups.last]
      end

      it 'can be hidden' do
        other_tag_groups.each do |t|
          expect(instance.can_hide?(t)).to be_truthy
        end
      end
    end
  end

  describe '#all_tag?' do
    subject { instance.all_tag?(tag_groups) }
    let(:other_tag_groups) do
      tag_groups.reject { |t| t[:tag] == '*' }
    end

    let(:all_tag_group) do
      tag_groups.select { |t| t[:tag] == '*' }
    end

    it 'returns false for tags not configured as "*"' do
      other_tag_groups.each do |t|
        expect(instance.all_tag?(t)).to be_falsey
      end
    end

    it 'returns true for tags configured as "*"' do
      all_tag_group.each do |t|
        expect(instance.all_tag?(t)).to be_truthy
      end
    end
  end
end
