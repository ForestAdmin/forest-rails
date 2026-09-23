require 'rails_helper'

# What the query loads on its own, outside the projection — a relation a scope joins, one an
# association scope includes, one a smart field declares on a relation the caller also projects —
# must survive the narrowed SELECT.
describe 'A projection alongside loads the request never named', type: :request do
  let(:scopes) { {} }

  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    Rails.cache.write('forest.has_permission', false)
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return('scopes' => scopes, 'team' => { 'id' => '1', 'name' => 'Operations' })
  end

  token = JWT.encode({ id: 38, email: 'michael.kelso@that70.show', first_name: 'Michael',
                       last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                       exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                     ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }
  page = { 'number' => '1', 'size' => '10' }

  let!(:owner) { User.create!(name: 'Michel', title: :king) }
  let!(:tree) { Tree.create!(name: 'Lemon Tree', owner: owner, cutter: owner) }

  def body
    JSON.parse(response.body)
  end

  # Tree#owner_name_declared declares dependencies: ['owner:name']. When the caller also projects
  # owner, the relation is built off the JOIN with only the projected columns, and the preloader
  # leaves an already-loaded association alone — the declared column has to reach the select.
  describe 'a smart field depending on a relation the caller projects with other columns' do
    let(:fields) { { 'Tree' => 'id,name,owner,owner_name_declared', 'owner' => 'title' } }

    it 'serves the declared value on the list' do
      get '/forest/Tree', params: { fields: fields, page: page, searchExtended: '0', timezone: 'Europe/Paris' },
                          headers: headers

      expect(response.status).to eq(200)
      expect(body['data'].map { |row| row['attributes']['owner_name_declared'] }).to eq(['Michel'])
      expect(body['included'].first['attributes']).to eq('title' => 'king')
    end

    it 'serves the declared value on the get-one' do
      get "/forest/Tree/#{tree.id}", params: { fields: fields, timezone: 'Europe/Paris' }, headers: headers

      expect(response.status).to eq(200)
      expect(body['data']['attributes']['owner_name_declared']).to eq('Michel')
    end

    it 'never falls back to a reload' do
      expect(FOREST_REPORTER).not_to receive(:report)
      expect(FOREST_LOGGER).not_to receive(:warn)

      get '/forest/Tree', params: { fields: fields, page: page, searchExtended: '0', timezone: 'Europe/Paris' },
                          headers: headers
    end
  end

  # A scope joins owner through FiltersParser; unprojected, that JOIN used to select none of its
  # columns, leaving the association loaded with a nil target the smart field then read.
  describe 'a scope filtering on a relation the projection does not name' do
    let(:scopes) do
      { 'Tree' => { 'aggregator' => 'and', 'conditions' => [{ 'field' => 'owner:name', 'operator' => 'present' }] } }
    end
    let(:fields) { { 'Tree' => 'id,name,owner_name_declared' } }

    it 'serves a smart field walking that relation on the list' do
      get '/forest/Tree', params: { fields: fields, page: page, searchExtended: '0', timezone: 'Europe/Paris' },
                          headers: headers

      expect(response.status).to eq(200)
      expect(body['data'].map { |row| row['attributes']['owner_name_declared'] }).to eq(['Michel'])
    end

    it 'serves a smart field walking that relation on the get-one' do
      get "/forest/Tree/#{tree.id}", params: { fields: fields, timezone: 'Europe/Paris' }, headers: headers

      expect(response.status).to eq(200)
      expect(body['data']['attributes']['owner_name_declared']).to eq('Michel')
    end
  end

  # Owner#trees_with_owner carries `includes(:owner)`: the preloader reads trees.owner_id off
  # every row, which a projection naming only id and name used to leave out of the SELECT.
  describe 'a related list through an association scope that preloads on its own' do
    let!(:tree_owner) { Owner.create!(name: 'Planter', hired_at: Time.now) }

    before { tree.update!(owner_id: tree_owner.id) }

    it 'answers the projected columns' do
      get "/forest/Owner/#{tree_owner.id}/relationships/trees_with_owner",
          params: { fields: { 'Tree' => 'id,name' }, page: page, timezone: 'Europe/Paris' }, headers: headers

      expect(response.status).to eq(200)
      expect(body['data'].map { |row| row['attributes'] }).to eq([{ 'id' => tree.id, 'name' => 'Lemon Tree' }])
    end
  end
end
