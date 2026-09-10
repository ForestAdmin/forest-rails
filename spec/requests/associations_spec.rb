require 'rails_helper'

describe 'Requesting an association', :type => :request do
  let(:scope_filters) { { 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } } }

  before do
    @user = User.create(name: 'Michel')
    @island = Island.create(name: 'Lemon Island')
    @tree = Tree.create(name: 'Lemon Tree', owner: @user, cutter: @user, island: @island)

    Rails.cache.write('forest.users', { '1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } })
    Rails.cache.write('forest.has_permission', true)
    Rails.cache.delete('forest.collections') # force a fresh fetch through the stub below, not a leftover from an earlier example
    enabled = { 'roles' => [1] }
    # read_permissions may force a real refetch on a denial (a stale cache may sit behind a
    # just-granted permission) — stub the source instead of writing the derived cache directly,
    # so that refetch sees the same permissions rather than hitting the network.
    allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
      .with('/liana/v4/permissions/environment').and_return(
        'collections' => {
          'Tree' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
          'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
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

  describe 'index, a malformed explicit projection' do
    it 'responds 422 naming the offending part, rather than a 500' do
      get "/forest/Island/#{@island.id}/relationships/trees",
          params: { fields: { 'Tree' => 'unknown:id' }, page: { 'number' => '1', 'size' => '10' }, timezone: 'Europe/Paris' },
          headers: headers

      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'][0]['detail']).to eq "Relation not found: 'Tree.unknown'"
    end
  end

  # Unlike index/show/update, an explicitly named but unreadable column drops silently instead
  # of refusing the whole file — matching agent-nodejs's own CSV route (same redactProjection,
  # same named-vs-not distinction it already applies to its JSON list, not a CSV-specific rule).
  describe 'csv export, naming a field of a collection the role cannot read' do
    it 'drops the unreadable column silently instead of refusing the whole export' do
      get "/forest/Island/#{@island.id}/relationships/trees.csv",
          params: { fields: { 'Tree' => 'id,name,owner' }, header: 'id,name,owner' },
          headers: headers

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to include('text/csv')
      csv_lines = response.body.split("\n")
      expect(csv_lines.first).to eq('id,name')
      expect(csv_lines[1]).to eq('1,Lemon Tree')
    end
  end

  describe 'csv export, an ordinary request naming only readable fields' do
    it 'serves the csv normally' do
      get "/forest/Island/#{@island.id}/relationships/trees.csv",
          params: { fields: { 'Tree' => 'id,name' }, header: 'id,name' },
          headers: headers

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to include('text/csv')
      csv_lines = response.body.split("\n")
      expect(csv_lines[1]).to eq('1,Lemon Tree')
    end
  end
end
