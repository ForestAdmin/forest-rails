require 'rails_helper'

describe 'Requesting Tree resources', :type => :request  do
  let(:scope_filters) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
  before do
    user = User.create(name: 'Michel')
    tree = Tree.create(name: 'Lemon Tree', owner: user, cutter: user)
    island = Island.create(name: 'Lemon Island', trees: [tree])
    Location.create(coordinates: '1,2', island: island)

    Rails.cache.write('forest.users', {'1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' }})
    Rails.cache.write('forest.has_permission', true)
    Rails.cache.write(
      'forest.collections',
      {
        'Tree' => {
          'browse'  => [1],
          'read'    => [1],
          'edit'    => [1],
          'add'     => [1],
          'delete'  => [1],
          'export'  => [1],
          'actions' => {}
        },
        'Location' => {
          'browse'  => [1],
          'read'    => [1],
          'edit'    => [1],
          'add'     => [1],
          'delete'  => [1],
          'export'  => [1],
          'actions' => {}
        },
        'User' => {
          'browse'  => [1],
          'read'    => [1],
          'edit'    => [1],
          'add'     => [1],
          'delete'  => [1],
          'export'  => [1],
          'actions' => {}
        }
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
    id: 1,
    email: 'michael.kelso@that70.show',
    first_name: 'Michael',
    last_name: 'Kelso',
    team: 'Operations',
    rendering_id: 16,
    exp: Time.now.to_i + 2.weeks.to_i,
    permission_level: 'admin'
  }, ForestLiana.auth_secret, 'HS256')

  headers = {
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{token}"
  }

  describe 'index' do
    describe 'without any filter' do
      params = {
        fields: { 'Tree' => 'id,name,location' },
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris'
      }

      it 'should respond 200' do
        get '/forest/Tree', params: params, headers: headers
        expect(response.status).to eq(200)
      end

      it 'should return 403 when user permission is not allowed' do
        Rails.cache.delete('forest.users')
        Rails.cache.write('forest.users', {'1' => { 'id' => 1, 'roleId' => 2, 'rendering_id' => '1' }})
        allow_any_instance_of(ForestLiana::Ability::Fetch)
          .to receive(:get_permissions)
                .with('/liana/v4/permissions/environment')
                .and_return(
                  {
                    "collections" => {
                      "Tree" => {
                        "collection" => {
                          "browseEnabled" => { "roles" => [1] },
                          "readEnabled" => { "roles" => [1] },
                          "editEnabled" => { "roles" => [1] },
                          "addEnabled" => { "roles" => [1] },
                          "deleteEnabled" => { "roles" => [1] },
                          "exportEnabled" => { "roles" => [1] }
                        },
                        "actions"=> {}
                      }
                    }
                  }
                )

        get '/forest/Tree', params: params, headers: headers

        expect(response.status).to eq(403)
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq 'You don\'t have permission to access this resource'
      end

      it 'should respond the tree data' do
        get '/forest/Tree', params: params, headers: headers
        
        expect(JSON.parse(response.body)).to include({
          "data" => [{
            "type" => "Tree",
            "id" => "1",
            "attributes" => {
              "id" => 1,
              "name" => "Lemon Tree"
            },
            "links" => {
              "self" => "/forest/tree/1"
            },
            "relationships" => {
              "location" => {
                "data" => { "id" => "1", "type" => "Location" },
                "links" => { "related" => {} }
              }
            }
          }],
          "included" => [{
            "type" => "Location",
            "id" => "1",
            "links" => { "self" => "/forest/location/1" }
          }]
        })
      end
    end

    describe 'with a filter on an association that is not a displayed column' do
      params = {
        fields: { 'Tree' => 'id,name' },
        filters: JSON.generate({
          field: 'owner:id',
          operator: 'present'
        }),
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris'
      }

      it 'should respond 200' do
        get '/forest/Tree', params: params, headers: headers
        expect(response.status).to eq(200)
      end

      it 'should respond the tree data' do
        get '/forest/Tree', params: params, headers: headers
        expect(JSON.parse(response.body)).to eq({
          "data" => [{
            "type" => "Tree",
            "id" => "1",
            "attributes" => {
              "id" => 1,
              "name" => "Lemon Tree"
            },
            "links" => {
              "self" => "/forest/tree/1"
            }
          }],
          "included" => []
        })
      end
    end
  end

  describe 'read-permission redaction' do
    describe 'index, naming a field of a collection the role cannot read' do
      params = {
        fields: { 'Tree' => 'id,name,island' },
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris'
      }

      it 'refuses with a 403 naming every offending field, not a silently shortened payload' do
        get '/forest/Tree', params: params, headers: headers

        expect(response.status).to eq(403)
        body = JSON.parse(response.body)
        expect(body['errors'][0]['detail'])
          .to eq "You are not allowed to read 'island' from the 'Island' collection."
        expect(body['errors'][0]['data']).to eq('fields' => ['island'])
      end
    end

    describe 'index, an ordinary listing that never named the unreadable relation' do
      params = {
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris'
      }

      it 'succeeds, with that relation silently absent rather than refusing the whole listing' do
        get '/forest/Tree', params: params, headers: headers

        expect(response.status).to eq(200)
        body = JSON.parse(response.body)
        expect(body['data'][0]['relationships']).not_to have_key('island')
        expect(body['data'][0]['relationships']).to have_key('location')
      end
    end

    it 'treats the very same denied path differently depending on whether the caller named it' do
      unnamed_params = {
        page: { 'number' => '1', 'size' => '10' }, searchExtended: '0', sort: '-id', timezone: 'Europe/Paris'
      }
      named_params = unnamed_params.merge(fields: { 'Tree' => 'id,name,island' })

      get '/forest/Tree', params: unnamed_params, headers: headers
      expect(response.status).to eq(200)

      get '/forest/Tree', params: named_params, headers: headers
      expect(response.status).to eq(403)
    end

    describe 'show' do
      it 'redacts the fields of a relation the role cannot read instead of refusing the whole record' do
        tree_id = Tree.first.id

        get "/forest/Tree/#{tree_id}", params: { timezone: 'Europe/Paris' }, headers: headers

        expect(response.status).to eq(200)
        body = JSON.parse(response.body)
        expect(body['data']['relationships']).not_to have_key('island')
        expect(body['data']['relationships']).to have_key('location')
      end
    end

    describe 'update' do
      it 'redacts the response of a write instead of refusing it' do
        tree_id = Tree.first.id

        put "/forest/Tree/#{tree_id}",
              params: { data: { type: 'Tree', id: tree_id.to_s, attributes: { name: 'Renamed' } } },
              headers: headers, as: :json

        expect(response.status).to eq(200)
        body = JSON.parse(response.body)
        expect(body['data']['attributes']['name']).to eq('Renamed')
        expect(body['data']['relationships']).not_to have_key('island')
      end
    end
  end

  describe 'read-permission enforcement on filter and sort' do
    it 'lets a malformed filter reach the parser\'s own 422, rather than crashing this guard' do
      params = {
        filters: JSON.generate({ 'operator' => 'equal', 'value' => 'x' }),
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        timezone: 'Europe/Paris'
      }

      get '/forest/Tree', params: params, headers: headers

      expect(response.status).to eq(422)
      expect(JSON.parse(response.body)['errors'][0]['detail']).to eq 'Invalid condition format'
    end

    describe 'filtering on a column of a collection the role cannot read' do
      params = {
        filters: JSON.generate({ 'field' => 'island:name', 'operator' => 'equal', 'value' => 'Lemon Island' }),
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        timezone: 'Europe/Paris'
      }

      it 'refuses index with a 403 naming the path and the collection' do
        get '/forest/Tree', params: params, headers: headers

        expect(response.status).to eq(403)
        body = JSON.parse(response.body)
        expect(body['errors'][0]['detail'])
          .to eq "You cannot filter on 'island:name': you are not allowed to read the 'Island' collection."
        expect(body['errors'][0]['data']).to eq('action' => 'filter on', 'field' => 'island:name', 'collections' => ['Island'])
      end

      it 'refuses count the same way' do
        get '/forest/Tree/count', params: params, headers: headers

        expect(response.status).to eq(403)
      end

      it 'refuses csv export the same way' do
        get '/forest/Tree.csv', params: params.merge(header: 'id'), headers: headers

        expect(response.status).to eq(403)
      end
    end

    describe 'sorting on a column of a collection the role cannot read' do
      params = {
        sort: '-island.name',
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        timezone: 'Europe/Paris'
      }

      it 'refuses index' do
        get '/forest/Tree', params: params, headers: headers

        expect(response.status).to eq(403)
        expect(JSON.parse(response.body)['errors'][0]['detail'])
          .to eq "You cannot sort on 'island:name': you are not allowed to read the 'Island' collection."
      end

      it 'does not refuse count, which never applies the sort' do
        get '/forest/Tree/count', params: params, headers: headers

        expect(response.status).to eq(200)
      end
    end

    it 'never checks a scope, even one referencing a column of an unreadable collection' do
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(
        'scopes' => {
          'Tree' => { 'aggregator' => 'and', 'conditions' => [{ 'field' => 'island:name', 'operator' => 'present' }] }
        },
        'team' => { 'id' => '1', 'name' => 'Operations' }
      )
      params = { page: { 'number' => '1', 'size' => '10' }, searchExtended: '0', timezone: 'Europe/Paris' }

      get '/forest/Tree', params: params, headers: headers

      expect(response.status).to eq(200)
    end

    it 'never refuses a filter on the root collection, even when the root has no read permission of its own' do
      # `browse` (not `read`) is what forest_authorize! gates the route on; a role can legitimately
      # browse a collection without having its own `read` — the root is still pinned readable for
      # this guard, which must not re-derive a denial for it from a permission it is not gated on.
      Rails.cache.write('forest.collections', { 'Tree' => { 'browse' => [1], 'read' => [], 'edit' => [], 'add' => [], 'delete' => [], 'export' => [], 'actions' => {} } })
      params = {
        filters: JSON.generate({ 'field' => 'name', 'operator' => 'present' }),
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        timezone: 'Europe/Paris'
      }

      get '/forest/Tree', params: params, headers: headers

      expect(response.status).to eq(200)
    end
  end

  describe 'read-permission enforcement on search' do
    describe 'an extended search reaching a column of a collection the role cannot read' do
      params = {
        search: 'Lemon',
        searchExtended: '1',
        page: { 'number' => '1', 'size' => '10' },
        timezone: 'Europe/Paris'
      }

      it 'refuses index with a 403 naming the path and the collection' do
        get '/forest/Tree', params: params, headers: headers

        expect(response.status).to eq(403)
        body = JSON.parse(response.body)
        expect(body['errors'][0]['detail'])
          .to eq "You cannot search on 'island:name': you are not allowed to read the 'Island' collection."
        expect(body['errors'][0]['data']).to eq('action' => 'search on', 'field' => 'island:name', 'collections' => ['Island'])
      end

      # `resources#count` had no specific rescue for this family of errors: pins that it carries
      # the same `name`/`data` payload as index, not the generic ExpectedError shape it fell into.
      it 'refuses count the same way, with the same name/data payload as index' do
        get '/forest/Tree/count', params: params, headers: headers

        expect(response.status).to eq(403)
        body = JSON.parse(response.body)
        expect(body['errors'][0]['name']).to eq('UnauthorizedQueryFieldError')
        expect(body['errors'][0]['data']).to eq('action' => 'search on', 'field' => 'island:name', 'collections' => ['Island'])
      end
    end

    it 'serves a plain search reaching the same column, since search stays root-only unless extended' do
      params = {
        search: 'Lemon',
        searchExtended: '0',
        page: { 'number' => '1', 'size' => '10' },
        timezone: 'Europe/Paris'
      }

      get '/forest/Tree', params: params, headers: headers

      expect(response.status).to eq(200)
    end
  end

  describe 'csv' do
    it 'should return CSV with correct headers and data' do
      params = {
        fields: { 'Tree' => 'id,name,owner', 'owner' => 'name'},
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris',
        header: 'id,name,owner',
      }
      get '/forest/Tree.csv', params: params, headers: headers

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')

      csv_content = response.body
      csv_lines = csv_content.split("\n")

      expect(csv_lines.first).to eq(params[:header])
      expect(csv_lines[1]).to eq('1,Lemon Tree,Michel')
    end

    it 'returns CSV with only requested fields and ignores optional relation' do
      params = {
        fields: { 'Tree' => 'id,name', 'owner' => 'name'},
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris',
        header: 'id,name',
      }
      get '/forest/Tree.csv', params: params, headers: headers

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')

      csv_content = response.body
      csv_lines = csv_content.split("\n")

      expect(csv_lines.first).to eq(params[:header])
      expect(csv_lines[1]).to eq('1,Lemon Tree')
    end
  end
end

describe 'Requesting User resources', :type => :request  do
  describe 'index' do
    before do
      User.create(name: 'John')

      Rails.cache.write('forest.users', {'1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' }})
      Rails.cache.write('forest.has_permission', true)
      Rails.cache.write(
        'forest.collections',
        {
          'User' => {
            'browse'  => [1],
            'read'    => [1],
            'edit'    => [1],
            'add'     => [1],
            'delete'  => [1],
            'export'  => [1],
            'actions' => {}
          }
        }
      )

      allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
      allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
      allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(
        {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}}
      )
    end

    after do
      User.destroy_all
    end

    it 'should respond the user data with meta when search apply on simple column and smart field' do
      token = JWT.encode({
        id: 1,
        email: 'michael.kelso@that70.show',
        first_name: 'Michael',
        last_name: 'Kelso',
        team: 'Operations',
        rendering_id: 16,
        exp: Time.now.to_i + 2.weeks.to_i,
        permission_level: 'admin'
      }, ForestLiana.auth_secret, 'HS256')

      headers = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }
      
      params = {
        fields: { 'User' => 'id,name,cap_name' },
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        search: 'JOHN',
        sort: '-id',
        timezone: 'Europe/Paris'
      }

      allow(ForestAdmin::JSONAPI::Serializer).to receive(:serialize).and_return(
        { "data" => [
          {
            "type" => "User",
            "id" => "1",
            "attributes" => { "id" => 1, "name" => "John", "cap_name" => "JOHN" },
            "links" => { "self" => "/forest/user/1" }
          }
        ], "included" => [] }
      )

      get '/forest/User', params: params, headers: headers

      expect(JSON.parse(response.body)).to include(
        "data" => [
          {
            "type" => "User",
            "id" => "1",
            "attributes" => {
              "id" => 1,
              "name" => "John",
              "cap_name" => "JOHN"
            },
            "links" => { "self" => "/forest/user/1" },
          }
        ],
        "included" => [],
        "meta" => { 'decorators' => { '0' => { 'id' => "1", 'search' => %w[name cap_name] } } }
      )
    end

    it 'refuses an extended search on a collection whose only search surface beyond it is a smart field lambda' do
      token = JWT.encode({
        id: 1,
        email: 'michael.kelso@that70.show',
        first_name: 'Michael',
        last_name: 'Kelso',
        team: 'Operations',
        rendering_id: 16,
        exp: Time.now.to_i + 2.weeks.to_i,
        permission_level: 'admin'
      }, ForestLiana.auth_secret, 'HS256')

      headers = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }

      params = {
        fields: { 'User' => 'id,name,cap_name' },
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '1',
        search: 'JOHN',
        timezone: 'Europe/Paris'
      }

      get '/forest/User', params: params, headers: headers

      expect(response.status).to eq(403)
      expect(JSON.parse(response.body)['errors'][0]['detail']).to eq(
        "You cannot run an extended search on the 'User' collection: the fields it reaches cannot " \
          'be determined, so they cannot be checked against your permissions.'
      )
    end
  end
end

describe 'Requesting Island resources', :type => :request  do
  let(:scope_filters) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
  before do
    island = Island.create(name: 'Paradise Island')
    Location.create(coordinates: '10,20', island: island)

    Rails.cache.write('forest.users', {'1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' }})
    Rails.cache.write('forest.has_permission', true)
    Rails.cache.write(
      'forest.collections',
      {
        'Island' => {
          'browse'  => [1],
          'read'    => [1],
          'edit'    => [1],
          'add'     => [1],
          'delete'  => [1],
          'export'  => [1],
          'actions' => {}
        }
      }
    )

    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scope_filters)
  end

  after do
    Island.destroy_all
    Location.destroy_all
  end

  token = JWT.encode({
    id: 1,
    email: 'michael.kelso@that70.show',
    first_name: 'Michael',
    last_name: 'Kelso',
    team: 'Operations',
    rendering_id: 16,
    exp: Time.now.to_i + 2.weeks.to_i,
    permission_level: 'admin'
  }, ForestLiana.auth_secret, 'HS256')

  headers = {
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{token}"
  }

  describe 'csv' do
    it 'should return CSV with has_one association without SQL error' do
      params = {
        fields: { 'Island' => 'id,name,location', 'location' => 'coordinates'},
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris',
        header: 'id,name,location',
      }
      get '/forest/Island.csv', params: params, headers: headers

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')

      csv_content = response.body
      csv_lines = csv_content.split("\n")

      expect(csv_lines.first).to eq(params[:header])
      expect(csv_lines[1]).to eq('1,Paradise Island,"10,20"')
    end
  end
end

describe 'Requesting Address resources', :type => :request  do
  let(:scope_filters) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
  before do
    user = User.create(name: 'Michel')
    Address.create(line1: '10 Downing Street', city: 'London', zipcode: '2AB', addressable: user)

    Rails.cache.write('forest.users', {'1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' }})
    Rails.cache.write('forest.has_permission', true)
    Rails.cache.write(
      'forest.collections',
      {
        'Address' => {
          'browse'  => [1],
          'read'    => [1],
          'edit'    => [1],
          'add'     => [1],
          'delete'  => [1],
          'export'  => [1],
          'actions' => {}
        },
        'User' => {
          'browse'  => [1],
          'read'    => [1],
          'edit'    => [1],
          'add'     => [1],
          'delete'  => [1],
          'export'  => [1],
          'actions' => {}
        }
      }
    )

    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scope_filters)
  end

  after do
    User.destroy_all
    Address.destroy_all
  end

  token = JWT.encode({
    id: 1,
    email: 'michael.kelso@that70.show',
    first_name: 'Michael',
    last_name: 'Kelso',
    team: 'Operations',
    rendering_id: 16,
    exp: Time.now.to_i + 2.weeks.to_i,
    permission_level: 'admin'
  }, ForestLiana.auth_secret, 'HS256')

  headers = {
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{token}"
  }

  describe 'index' do
    params = {
      fields: { 'Address' => 'id,line1,city,zip_code,addressable' },
      page: { 'number' => '1', 'size' => '10' },
      searchExtended: '0',
      sort: '-id',
      timezone: 'Europe/Paris'
    }

    it 'should respond the address data' do
      get '/forest/Address', params: params, headers: headers

      expect(JSON.parse(response.body)).to include(
        "data" => [
          {
            "type" => "Address",
            "id" => "1",
            "attributes" => {
              "id" => 1,
              "line1" => "10 Downing Street",
              "city" => "London"
            },
            "links" => { "self" => "/forest/address/1" },
            "relationships" => {
              "addressable" => { "links" => { "related" => {} }, "data" => { "type" => "User", "id" => "1" } }
            }
          }
        ]
      )
    end
  end

  describe 'csv' do
    it 'should return CSV with polymorphic association' do
      params = {
        fields: { 'Address' => 'id,line1,city,addressable', 'addressable' => 'name'},
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris',
        header: 'id,line1,city,addressable',
      }
      get '/forest/Address.csv', params: params, headers: headers

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')

      csv_content = response.body
      csv_lines = csv_content.split("\n")

      expect(csv_lines.first).to eq(params[:header])
      expect(csv_lines[1]).to eq('1,10 Downing Street,London,Michel')
    end

    it 'should return CSV with only requested fields and ignore optional polymorphic relation' do
      params = {
        fields: { 'Address' => 'id,line1,city', 'addressable' => 'name'},
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris',
        header: 'id,line1,city',
      }
      get '/forest/Address.csv', params: params, headers: headers

      expect(response.status).to eq(200)
      expect(response.headers['Content-Type']).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')

      csv_content = response.body
      csv_lines = csv_content.split("\n")

      expect(csv_lines.first).to eq(params[:header])
      expect(csv_lines[1]).to eq('1,10 Downing Street,London')
    end
  end
end
