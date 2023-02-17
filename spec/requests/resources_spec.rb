require 'rails_helper'

describe 'Requesting Tree resources', :type => :request  do

  before do
    user = User.create(name: 'Michel')
    tree = Tree.create(name: 'Lemon Tree', owner: user, cutter: user)

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
    # allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return({})
  end

  after do
    User.destroy_all
    Tree.destroy_all
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
        fields: { 'Tree' => 'id,name' },
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
end
