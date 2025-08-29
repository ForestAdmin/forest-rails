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
end
