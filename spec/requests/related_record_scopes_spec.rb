require 'rails_helper'

describe 'Related records outside their collection scope', type: :request do
  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    Rails.cache.write('forest.has_permission', false)
    ForestLiana::ScopeManager.invalidate_scope_cache(16)
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return({
      'scopes' => {
        'User' => { 'aggregator' => 'and', 'conditions' => [{ 'field' => 'name', 'operator' => 'equal', 'value' => 'Michel' }] }
      },
      'related_record_scopes' => ['User'],
      'team' => { 'id' => '1', 'name' => 'Operations' }
    })
  end

  after { [Tree, User, Island].each(&:delete_all) }

  token = JWT.encode({ id: 38, email: 'michael.kelso@that70.show', first_name: 'Michael',
                       last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                       exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                     ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }

  let!(:island) { Island.create!(name: 'Skull') }
  let!(:michel) { User.create!(name: 'Michel') }
  let!(:robert) { User.create!(name: 'Robert') }
  let!(:ginger) { Tree.create!(name: 'Ginger Tree', island: island, owner: robert, cutter: michel) }
  let!(:lemon) { Tree.create!(name: 'Lemon Tree', island: island, owner: michel, cutter: michel) }

  # The emptied owner, and whether the hidden user still appears anywhere in the included records.
  def served_owner
    body = JSON.parse(response.body)
    owner = body['data']['relationships']['owner']['data']
    leaked = (body['included'] || []).any? { |entry| entry['type'] == 'User' && entry['id'] == robert.id.to_s }

    [owner, leaked]
  end

  it 'serves an updated record with its out-of-scope owner emptied' do
    put "/forest/Tree/#{ginger.id}",
        params: { data: { type: 'Tree', id: ginger.id.to_s, attributes: { name: 'Renamed' } } },
        headers: headers, as: :json

    expect(response.status).to eq(200)
    expect(served_owner).to eq([nil, false])
  end

  it 'serves a created record with its out-of-scope owner emptied' do
    post '/forest/Tree',
         params: { data: { type: 'Tree', attributes: { name: 'Lemon Tree' },
                           relationships: { owner: { data: { type: 'User', id: robert.id.to_s } },
                                            cutter: { data: { type: 'User', id: michel.id.to_s } },
                                            island: { data: { type: 'Island', id: island.id.to_s } } } } },
         headers: headers, as: :json

    expect(response.status).to eq(200)
    expect(served_owner).to eq([nil, false])
  end

  it 'serves an in-scope owner unchanged on update' do
    put "/forest/Tree/#{lemon.id}",
        params: { data: { type: 'Tree', id: lemon.id.to_s, attributes: { name: 'Renamed' } } },
        headers: headers, as: :json

    expect(response.status).to eq(200)
    expect(JSON.parse(response.body)['data']['relationships']['owner']['data']).to eq({ 'type' => 'User', 'id' => michel.id.to_s })
  end
end
