require 'rails_helper'

describe 'MissingAttributeValve', type: :request do
  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    Rails.cache.write('forest.has_permission', false)
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return({ 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } })
  end

  token = JWT.encode({ id: 38, email: 'michael.kelso@that70.show', first_name: 'Michael',
                        last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                        exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                      ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }

  # User#name_with_title (spec/dummy's fixture) declares dependencies: ['name'] but its getter
  # also reads title — deliberately incomplete, the exact mistake this valve exists for.
  describe 'a Smart Field whose declared dependencies are incomplete' do
    let!(:user) { User.create!(name: 'Michel', title: :king) }

    it 'still serves the correct value, reloading once rather than crashing or returning nil' do
      queries = capture_queries do
        get '/forest/User', params: { fields: { 'User' => 'id,name_with_title' }, page: { number: '1', size: '10' },
                                       searchExtended: '0', timezone: 'Europe/Paris' }, headers: headers
      end

      expect(response.status).to eq 200
      body = JSON.parse(response.body)
      expect(body['data'][0]['attributes']['name_with_title']).to eq('Michel (king)')
      expect(selects_from(queries, 'users').size).to eq(2) # the original projected select, then the reload
    end

    it 'warns once, and never reports to FOREST_REPORTER, on a successful retry' do
      expect(FOREST_LOGGER).to receive(:warn).once.with(/name_with_title.*title/m)
      expect(FOREST_REPORTER).not_to receive(:report)

      get '/forest/User', params: { fields: { 'User' => 'id,name_with_title' }, page: { number: '1', size: '10' },
                                     searchExtended: '0', timezone: 'Europe/Paris' }, headers: headers
    end

    # The row can vanish between the list query and serialization (a concurrent delete) — #reload
    # itself raising must degrade the same way a second MissingAttributeError would, not escape
    # this valve entirely.
    it 'degrades to nil rather than crash when the reload itself raises' do
      allow_any_instance_of(User).to receive(:reload).and_raise(ActiveRecord::RecordNotFound)
      expect(FOREST_REPORTER).to receive(:report)

      get '/forest/User', params: { fields: { 'User' => 'id,name_with_title' }, page: { number: '1', size: '10' },
                                     searchExtended: '0', timezone: 'Europe/Paris' }, headers: headers

      expect(response.status).to eq 200
      body = JSON.parse(response.body)
      expect(body['data'][0]['attributes']['name_with_title']).to be_nil
    end
  end

  # Tree#name_with_age (spec/dummy's fixture) declares dependencies: ['name'] but its getter also
  # reads age — the same incomplete-declaration mistake, on the record whose own reload must not
  # disturb an association already eager-loaded alongside it.
  describe 'an association already eager-loaded when the valve reloads the record' do
    let!(:owner) { User.create!(name: 'Michel', title: :king) }
    let!(:tree) { Tree.create!(name: 'Oak', age: 5, owner: owner, cutter: owner) }

    it 'does not re-query the joined relation, reload restores its already-loaded target' do
      queries = capture_queries do
        get '/forest/Tree', params: { fields: { 'Tree' => 'id,name_with_age,owner', 'owner' => 'name' },
                                       page: { number: '1', size: '10' }, searchExtended: '0', timezone: 'Europe/Paris' }, headers: headers
      end

      expect(response.status).to eq 200
      body = JSON.parse(response.body)
      expect(body['data'][0]['attributes']['name_with_age']).to eq('Oak (5)')
      # One reload of the tree row itself, once the incomplete projection misses age - the owner
      # join from the original query must survive that reload rather than being re-queried.
      expect(selects_from(queries, 'trees').size).to eq(2)
      expect(selects_from(queries, 'users').size).to eq(0)
    end
  end

  # Tree#owner_name_declared (spec/dummy's fixture) declares dependencies: ['owner:name'], a
  # relation-path crossing the belongs_to owner association — its own preload is out of scope
  # here, but the foreign key it needs must still be selected, or reading the association at all
  # (before ever reaching owner's own name) would raise on Tree's own missing owner_id.
  describe 'a smart field whose only declared dependency is a relation path' do
    let!(:owner) { User.create!(name: 'Michel', title: :king) }
    let!(:tree) { Tree.create!(name: 'Oak', age: 5, owner: owner, cutter: owner) }

    it "serves the value without ever hitting the valve, having selected the association's own foreign key" do
      expect(FOREST_LOGGER).not_to receive(:warn)
      expect(FOREST_REPORTER).not_to receive(:report)

      queries = capture_queries do
        get '/forest/Tree', params: { fields: { 'Tree' => 'id,owner_name_declared' },
                                       page: { number: '1', size: '10' }, searchExtended: '0', timezone: 'Europe/Paris' }, headers: headers
      end

      expect(response.status).to eq 200
      body = JSON.parse(response.body)
      expect(body['data'][0]['attributes']['owner_name_declared']).to eq('Michel')
      # Exactly the same footprint as an ordinary, non-preloaded belongs_to lookup: the tree's own
      # projected select (never reloaded) plus one lazy load of its owner — not two extra queries
      # (a wasted Tree reload, then the owner lookup) the way an unselected FK would cost.
      expect(selects_from(queries, 'trees').size).to eq(1)
      expect(selects_from(queries, 'users').size).to eq(1)
    end
  end

  # Tree#owner_name (spec/dummy's fixture) reads a column of the joined owner relation, narrowed
  # out of that relation's own projection — reloading the Tree row itself could never produce it.
  describe "a missing attribute that belongs to a joined relation's own record, not the root" do
    let!(:owner) { User.create!(name: 'Michel', title: :king) }
    let!(:tree) { Tree.create!(name: 'Oak', age: 5, owner: owner, cutter: owner) }

    it 'degrades to nil immediately, without reloading, since the root record cannot fix it' do
      expect(FOREST_LOGGER).not_to receive(:warn)
      expect(FOREST_REPORTER).to receive(:report)

      get '/forest/Tree', params: { fields: { 'Tree' => 'id,name,owner_name,owner', 'owner' => 'title' },
                                     page: { number: '1', size: '10' }, searchExtended: '0', timezone: 'Europe/Paris' }, headers: headers

      expect(response.status).to eq 200
      body = JSON.parse(response.body)
      expect(body['data'][0]['attributes']['owner_name']).to be_nil
    end
  end

  # Location#alter_coordinates (spec/dummy's fixture) reads object.name, which does not exist on
  # Location at all - a NoMethodError, not a MissingAttributeError. Rescued by the getter's own
  # existing rescue (lib/forest_liana/collection.rb) before it ever reaches the valve, and the
  # valve's own rescue clause is typed to MissingAttributeError alone regardless - degrades
  # exactly as it did before this valve existed, on both counts.
  describe 'a getter reading a genuinely non-existent method' do
    let!(:island) { Island.create!(name: 'Reunion') }
    let!(:location) { Location.create!(coordinates: '1,2', island: island) }

    it 'still degrades to nil without reloading, exactly as it did before this valve existed' do
      expect(FOREST_LOGGER).not_to receive(:warn)
      expect(FOREST_REPORTER).to receive(:report)

      get "/forest/Location/#{location.id}", headers: headers.merge('Forest-Projection' => 'id,coordinates,alter_coordinates')

      expect(response.status).to eq 200
      body = JSON.parse(response.body)
      expect(body['data']['attributes']['alter_coordinates']).to be_nil
    end
  end
end
