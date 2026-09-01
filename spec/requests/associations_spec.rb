require 'rails_helper'

describe 'Requesting an association', :type => :request do
  let(:scope_filters) { { 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } } }

  before do
    @user = User.create(name: 'Michel')
    @island = Island.create(name: 'Lemon Island')
    @tree = Tree.create(name: 'Lemon Tree', owner: @user, cutter: @user, island: @island)

    Rails.cache.write('forest.users', { '1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } })
    Rails.cache.write('forest.has_permission', true)
    Rails.cache.write(
      'forest.collections',
      {
        'Tree' => { 'browse' => [1], 'read' => [1], 'edit' => [1], 'add' => [1], 'delete' => [1], 'export' => [1], 'actions' => {} },
        'Island' => { 'browse' => [1], 'read' => [1], 'edit' => [1], 'add' => [1], 'delete' => [1], 'export' => [1], 'actions' => {} }
      }
    )

    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scope_filters)
  end

  after do
    User.destroy_all
    Tree.destroy_all
    Island.destroy_all
  end

  token = JWT.encode({
    id: 1, email: 'michael.kelso@that70.show', first_name: 'Michael', last_name: 'Kelso',
    team: 'Operations', rendering_id: 16, exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin'
  }, ForestLiana.auth_secret, 'HS256')

  headers = {
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{token}"
  }

  describe 'index, an ordinary listing that never named the unreadable relation' do
    it 'succeeds, with that relation silently absent rather than refusing the whole listing' do
      get "/forest/Island/#{@island.id}/relationships/trees",
          params: { page: { 'number' => '1', 'size' => '10' }, timezone: 'Europe/Paris' }, headers: headers

      expect(response.status).to eq(200)
      body = JSON.parse(response.body)
      expect(body['data'][0]['relationships']).not_to have_key('owner')
    end
  end

  describe 'index, naming a field of a collection the role cannot read' do
    it 'refuses with a 403 naming the offending field' do
      get "/forest/Island/#{@island.id}/relationships/trees",
          params: { fields: { 'Tree' => 'id,name,owner' }, page: { 'number' => '1', 'size' => '10' }, timezone: 'Europe/Paris' },
          headers: headers

      expect(response.status).to eq(403)
      body = JSON.parse(response.body)
      expect(body['errors'][0]['detail']).to eq "You are not allowed to read 'owner' from the 'User' collection."
      expect(body['errors'][0]['data']).to eq('fields' => ['owner'])
    end
  end
end
