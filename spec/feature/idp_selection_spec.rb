# frozen_string_literal: true

require 'spec_helper'

RSpec.feature 'selecting an idp', type: :feature do
  given(:entity_id) { Faker::Internet.url }
  given(:redis) { Redis::Namespace.new(:discovery_service, redis: Redis.new) }
  given(:path_for_group) { "/discovery/#{group_name}?entityID=#{entity_id}" }

  context 'when the group does not exist' do
    given(:group_name) { 'xyz' }
    it 'returns http status code 404' do
      visit path_for_group
      expect(page.status_code).to eq(404)
    end
  end

  context 'when the group exists' do
    given(:group_name) { 'aaf' }
    given(:content) { 'Content here' }
    include_context 'build_entity_data'

    background do
      redis.set("pages:group:#{group_name}", content)
    end

    it 'shows the content' do
      visit path_for_group
      expect(page).to have_content content
    end
  end
end
