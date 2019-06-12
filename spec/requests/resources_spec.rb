require 'rails_helper'

describe 'Requesting Tree resources', :type => :request  do
  before(:each) do
    user = User.create(name: 'Michel')
    tree = Tree.create(name: 'Lemon Tree', owner: user, cutter: user)
  end

  after(:each) do
    User.destroy_all
    Tree.destroy_all
  end

  before(:each) do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }

    allow_any_instance_of(ForestLiana::PermissionsChecker).to receive(:is_authorized?) { true }
  end

  token = JWT.encode({
    id: 38,
    email: 'michael.kelso@that70.show',
    first_name: 'Michael',
    last_name: 'Kelso',
    team: 'Operations',
    rendering_id: 16,
    exp: Time.now.to_i + 2.weeks.to_i
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
        get '/forest/Tree', params, headers
        expect(response.status).to eq(200)
      end

      it 'should respond the tree data' do
        get '/forest/Tree', params, headers
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
        filterType: 'and',
        filter: { 'owner:id' => '$present' },
        page: { 'number' => '1', 'size' => '10' },
        searchExtended: '0',
        sort: '-id',
        timezone: 'Europe/Paris'
      }

      it 'should respond 200' do
        get '/forest/Tree', params, headers
        expect(response.status).to eq(200)
      end

      it 'should respond the tree data' do
        get '/forest/Tree', params, headers
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
