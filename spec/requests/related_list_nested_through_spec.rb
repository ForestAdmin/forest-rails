require 'rails_helper'

describe 'A related list displaying a nested has_one :through', type: :request do
  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    Rails.cache.write('forest.has_permission', false)
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return('scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' })
  end

  token = JWT.encode({ id: 38, email: 'michael.kelso@that70.show', first_name: 'Michael',
                       last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                       exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                     ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }

  let!(:user) { User.create!(name: 'Michel', title: :king) }
  let!(:island) { Island.create!(name: 'Skull') }
  let!(:location) { Location.create!(coordinates: '12345', island: island) }
  let!(:membership) { Membership.create!(island: island, user: user) }

  it 'serves the relation the list displays' do
    get "/forest/Island/#{island.id}/relationships/memberships",
        params: { fields: { 'Membership' => 'id,location_island', 'location_island' => 'name' },
                  page: { 'number' => '1', 'size' => '15' }, sort: '-id', timezone: 'Europe/Paris' },
        headers: headers

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body['data'].map { |row| row.dig('relationships', 'location_island', 'data', 'id') }).to eq([island.id.to_s])
    expect(body['included'].map { |record| record.dig('attributes', 'name') }).to eq(['Skull'])
  end
end
