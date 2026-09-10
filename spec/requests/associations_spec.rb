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
    Location.destroy_all
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

  describe 'filtering on a column of a collection the role cannot read' do
    params = {
      filters: JSON.generate({ 'field' => 'owner:name', 'operator' => 'equal', 'value' => 'Michel' }),
      page: { 'number' => '1', 'size' => '10' },
      timezone: 'Europe/Paris'
    }

    it 'refuses index with a 403 naming the path and the collection' do
      get "/forest/Island/#{@island.id}/relationships/trees", params: params, headers: headers

      expect(response.status).to eq(403)
      body = JSON.parse(response.body)
      expect(body['errors'][0]['detail'])
        .to eq "You cannot filter on 'owner:name': you are not allowed to read the 'User' collection."
    end

    # This is the route that had no ExpectedError rescue at all before this guard: anything it
    # raised surfaced as a bare 500, not the 403 every other route already gave the same denial.
    it 'refuses count the same way, not with a bodiless 500' do
      get "/forest/Island/#{@island.id}/relationships/trees/count", params: params, headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail'])
        .to eq "You cannot filter on 'owner:name': you are not allowed to read the 'User' collection."
    end
  end

  describe 'sorting on a column of a collection the role cannot read' do
    params = { sort: '-owner.name', page: { 'number' => '1', 'size' => '10' }, timezone: 'Europe/Paris' }

    it 'refuses index' do
      get "/forest/Island/#{@island.id}/relationships/trees", params: params, headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail'])
        .to eq "You cannot sort on 'owner:name': you are not allowed to read the 'User' collection."
    end

    it 'does not refuse count, which never applies the sort' do
      get "/forest/Island/#{@island.id}/relationships/trees/count", params: params, headers: headers

      expect(response.status).to eq(200)
    end
  end

  describe 'an extended search reaching a column of a collection the role cannot read' do
    params = { search: 'Michel', searchExtended: '1', page: { 'number' => '1', 'size' => '10' }, timezone: 'Europe/Paris' }

    it 'refuses index with a 403 naming the path and the collection' do
      get "/forest/Island/#{@island.id}/relationships/trees", params: params, headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail'])
        .to eq "You cannot search on 'owner:name': you are not allowed to read the 'User' collection."
    end

    it 'refuses count the same way, since search (unlike sort) applies to it too' do
      get "/forest/Island/#{@island.id}/relationships/trees/count", params: params, headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail'])
        .to eq "You cannot search on 'owner:name': you are not allowed to read the 'User' collection."
    end
  end

  describe 'listing/counting a relation on a collection the role has zero permission on' do
    before do
      enabled = { 'roles' => [1] }
      disabled = { 'roles' => [] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Tree' => { 'collection' => { 'browseEnabled' => disabled, 'readEnabled' => disabled, 'editEnabled' => disabled, 'addEnabled' => disabled, 'deleteEnabled' => disabled, 'exportEnabled' => disabled }, 'actions' => {} },
            # Fully enabled so a wrong-collection check (User instead of Tree) shows up as a 204,
            # not an incidental 409 from an absent collection.
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')
    end

    it 'refuses index with a 403, rather than serving it unauthorized' do
      get "/forest/Island/#{@island.id}/relationships/trees",
          params: { page: { 'number' => '1', 'size' => '10' }, timezone: 'Europe/Paris' }, headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail']).to eq "You don't have permission to access this resource"
      expect(JSON.parse(response.body)['errors'][0]['name']).to eq('AccessDenied')
    end

    # Without forest_authorize!, a filtered count on a collection the role cannot even browse
    # answered with the real, filtered row count — letting the filter value be guessed one probe
    # at a time (0 vs a positive count) without ever touching a field-level read check.
    it 'refuses count with a 403, instead of a filtered count that leaks whether a value matches' do
      params = { filters: JSON.generate({ 'field' => 'name', 'operator' => 'equal', 'value' => 'Lemon Tree' }), timezone: 'Europe/Paris' }
      get "/forest/Island/#{@island.id}/relationships/trees/count", params: params, headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['name']).to eq('AccessDenied')
    end

    it 'refuses updating a belongsTo with a 403, checking edit on the parent (Tree)' do
      other_user = User.create(name: 'Other')
      params = { data: { type: 'User', id: other_user.id.to_s } }

      put "/forest/Tree/#{@tree.id}/relationships/owner", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['name']).to eq('AccessDenied')
      expect(@tree.reload.owner).to eq(@user)
    end

    it 'refuses associating with a 403, checking edit on the related collection (Tree)' do
      other_tree = Tree.create(name: 'Other Tree', owner: @user, cutter: @user)
      params = { data: [{ type: 'Tree', id: other_tree.id.to_s }] }

      post "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['name']).to eq('AccessDenied')
      expect(other_tree.reload.island).to be_nil
    end

    it 'refuses dissociating with a 403, checking edit (not delete) on the related collection (Tree)' do
      params = { data: [{ type: 'Tree', id: @tree.id.to_s }] }

      delete "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['name']).to eq('AccessDenied')
      expect(@tree.reload.island).to eq(@island)
    end

    it 'refuses a dissociate-and-delete with a 403, checking delete instead of edit' do
      params = { delete: 'true', data: [{ type: 'Tree', id: @tree.id.to_s }] }

      delete "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(Tree.exists?(@tree.id)).to be true
    end

    it 'refuses updating a has_one relation with a 403, checking edit on the target (Location), not the parent (Island)' do
      other_location = Location.create(coordinates: '9,9')
      params = { data: { type: 'Location', id: other_location.id.to_s } }

      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => { 'roles' => [1] }, 'readEnabled' => { 'roles' => [1] }, 'editEnabled' => { 'roles' => [1] }, 'addEnabled' => { 'roles' => [1] }, 'deleteEnabled' => { 'roles' => [1] }, 'exportEnabled' => { 'roles' => [1] } }, 'actions' => {} },
            'Location' => { 'collection' => { 'browseEnabled' => { 'roles' => [] }, 'readEnabled' => { 'roles' => [] }, 'editEnabled' => { 'roles' => [] }, 'addEnabled' => { 'roles' => [] }, 'deleteEnabled' => { 'roles' => [] }, 'exportEnabled' => { 'roles' => [] } }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      put "/forest/Island/#{@island.id}/relationships/location", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(@island.reload.location).to be_nil
    end
  end

  describe 'write actions on a relation, with edit granted but delete denied on the related collection' do
    before do
      enabled = { 'roles' => [1] }
      no_role = { 'roles' => [] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Tree' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => no_role, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')
    end

    # Island.trees has no dependent: option, so a plain unlink only nullifies Tree#island_id.
    it 'allows a plain dissociate (edit) but refuses the same call with delete: true' do
      params = { data: [{ type: 'Tree', id: @tree.id.to_s }] }
      delete "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(204)
      expect(@tree.reload.island).to be_nil

      params = { delete: 'true', data: [{ type: 'Tree', id: @tree.id.to_s }] }
      delete "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(Tree.exists?(@tree.id)).to be true
    end
  end

  describe 'write actions on a relation, with the necessary permission granted' do
    before do
      enabled = { 'roles' => [1] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Tree' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')
    end

    it 'lets an authorized role update a belongsTo' do
      other_user = User.create(name: 'Other')
      params = { data: { type: 'User', id: other_user.id.to_s } }

      put "/forest/Tree/#{@tree.id}/relationships/owner", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(204)
      expect(@tree.reload.owner).to eq(other_user)
    end

    it 'lets an authorized role associate an existing record' do
      other_tree = Tree.create(name: 'Other Tree', owner: @user, cutter: @user)
      params = { data: [{ type: 'Tree', id: other_tree.id.to_s }] }

      post "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(204)
      expect(other_tree.reload.island).to eq(@island)
    end

    it 'lets an authorized role dissociate a record' do
      params = { data: [{ type: 'Tree', id: @tree.id.to_s }] }

      delete "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(204)
      expect(@tree.reload.island).to be_nil
    end
  end

  describe 'select-all dissociate naming a filter on a collection the role cannot read' do
    it 'refuses with a 403 body instead of a bodiless 500' do
      params = {
        data: {
          attributes: {
            collection_name: 'Tree',
            all_records: true,
            all_records_subset_query: {
              filters: JSON.generate({ 'field' => 'owner:name', 'operator' => 'equal', 'value' => 'Michel' })
            }
          }
        }
      }

      delete "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail'])
        .to eq "You cannot filter on 'owner:name': you are not allowed to read the 'User' collection."
    end
  end

  describe 'select-all dissociate sorting on a collection the role cannot read' do
    it 'refuses with a 403, instead of reordering the ids to dissociate by an unreadable column' do
      params = {
        data: {
          attributes: {
            collection_name: 'Tree',
            all_records: true,
            all_records_subset_query: {
              sort: '-owner.name'
            }
          }
        }
      }

      delete "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail'])
        .to eq "You cannot sort on 'owner:name': you are not allowed to read the 'User' collection."
    end

    # Naming parent_collection_id/parent_collection_name/parent_association_name (rather than a
    # plain collection_name) is what actually routes get_ids_from_request through HasManyGetter —
    # the branch the sort-readability fix in initialize_resources_getter exists for in the first
    # place, and the only one of the two get_ids_from_request branches the other example above
    # doesn't reach.
    it 'refuses with a 403 through the related/HasManyGetter branch too, not just the plain collection one' do
      params = {
        data: {
          attributes: {
            parent_collection_id: @island.id.to_s,
            parent_collection_name: 'Island',
            parent_association_name: 'trees',
            all_records: true,
            all_records_subset_query: {
              sort: '-owner.name'
            }
          }
        }
      }

      delete "/forest/Island/#{@island.id}/relationships/trees", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail'])
        .to eq "You cannot sort on 'owner:name': you are not allowed to read the 'User' collection."
    end
  end

  describe 'associating a has_many :through relation' do
    after do
      Membership.destroy_all
    end

    # associate on a through association creates a join row (Membership), never touches the far
    # one (User) — so that's what edit has to be checked on, not User.
    it 'refuses with a 403, checking edit on the join collection (Membership)' do
      enabled = { 'roles' => [1] }
      no_role = { 'roles' => [] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Membership' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => no_role, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: [{ type: 'User', id: @user.id.to_s }] }
      post "/forest/Island/#{@island.id}/relationships/members", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(Membership.where(island: @island, user: @user)).to be_empty
    end

    it 'lets an authorized role associate it, creating the join row' do
      enabled = { 'roles' => [1] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Membership' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: [{ type: 'User', id: @user.id.to_s }] }
      post "/forest/Island/#{@island.id}/relationships/members", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(204)
      expect(Membership.where(island: @island, user: @user)).not_to be_empty
    end
  end

  describe 'updating a has_one relation whose reflection destroys the previous target' do
    after do
      Flag.destroy_all
    end

    it 'refuses with a 403, requiring delete in addition to edit on the target (Flag)' do
      old_flag = Flag.create(island: @island, color: 'red')
      new_flag = Flag.create(color: 'blue')
      enabled = { 'roles' => [1] }
      edit_only = { 'roles' => [1] }
      no_role = { 'roles' => [] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Flag' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => edit_only, 'addEnabled' => enabled, 'deleteEnabled' => no_role, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: { type: 'Flag', id: new_flag.id.to_s } }
      put "/forest/Island/#{@island.id}/relationships/flag", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(Flag.exists?(old_flag.id)).to be true
    end

    it 'lets an authorized role replace it, destroying the previous target' do
      old_flag = Flag.create(island: @island, color: 'red')
      new_flag = Flag.create(color: 'blue')
      enabled = { 'roles' => [1] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Flag' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: { type: 'Flag', id: new_flag.id.to_s } }
      put "/forest/Island/#{@island.id}/relationships/flag", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(204)
      expect(Flag.exists?(old_flag.id)).to be false
      expect(@island.reload.flag).to eq(new_flag)
    end
  end

  describe 'a has_many :through relation whose join model is excluded from the schema' do
    around do |example|
      previous = ForestLiana.excluded_models
      ForestLiana.excluded_models = ['Membership']
      example.run
    ensure
      ForestLiana.excluded_models = previous
    end

    after do
      Membership.destroy_all
    end

    it 'associate falls back to checking the far collection (User) instead of 409ing' do
      no_role = { 'roles' => [] }
      enabled = { 'roles' => [1] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => no_role, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: [{ type: 'User', id: @user.id.to_s }] }
      post "/forest/Island/#{@island.id}/relationships/members", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(Membership.where(island: @island, user: @user)).to be_empty
    end

    it 'associate still works end to end when the far collection (User) grants edit' do
      enabled = { 'roles' => [1] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: [{ type: 'User', id: @user.id.to_s }] }
      post "/forest/Island/#{@island.id}/relationships/members", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(204)
      expect(Membership.where(island: @island, user: @user)).not_to be_empty
    end

    # Island.members has no dependent: option, so a plain unlink destroys the join row (see
    # HasManyDissociator.destroys_on_unlink?) — the action checked here is delete, not edit.
    it 'dissociate falls back to checking the far collection (User) instead of 409ing' do
      @membership = Membership.create(island: @island, user: @user)
      no_role = { 'roles' => [] }
      enabled = { 'roles' => [1] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => no_role, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: [{ type: 'User', id: @user.id.to_s }] }
      delete "/forest/Island/#{@island.id}/relationships/members", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(Membership.exists?(@membership.id)).to be true
    end
  end

  describe 'dissociating a has_many :through relation' do
    before do
      @membership = Membership.create(island: @island, user: @user)
    end

    after do
      Membership.destroy_all
    end

    # A plain unlink on a through association only ever touches the join collection (Membership),
    # never the far one (User) — so that's what edit/delete has to be checked on, not User.
    it 'refuses a plain dissociate with a 403, checking delete on the join collection (Membership)' do
      enabled = { 'roles' => [1] }
      no_role = { 'roles' => [] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Membership' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => no_role, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: [{ type: 'User', id: @user.id.to_s }] }
      delete "/forest/Island/#{@island.id}/relationships/members", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(403)
      expect(Membership.exists?(@membership.id)).to be true
    end

    it 'lets an authorized role dissociate it, deleting the join row but leaving User intact' do
      enabled = { 'roles' => [1] }
      allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
        .with('/liana/v4/permissions/environment').and_return(
          'collections' => {
            'Island' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'User' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} },
            'Membership' => { 'collection' => { 'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => enabled, 'addEnabled' => enabled, 'deleteEnabled' => enabled, 'exportEnabled' => enabled }, 'actions' => {} }
          }
        )
      Rails.cache.delete('forest.collections')

      params = { data: [{ type: 'User', id: @user.id.to_s }] }
      delete "/forest/Island/#{@island.id}/relationships/members", params: JSON.dump(params), headers: headers

      expect(response.status).to eq(204)
      expect(Membership.exists?(@membership.id)).to be false
      expect(User.exists?(@user.id)).to be true
    end
  end
end
