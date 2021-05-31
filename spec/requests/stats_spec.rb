require 'rails_helper'
require 'json'

describe "Stats", type: :request do

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

  let(:schema) {
    [
      ForestLiana::Model::Collection.new({
        name: 'Products',
        fields: [],
        actions: []
      })
    ]
  }

  before do
    allow(ForestLiana).to receive(:apimap).and_return(schema)
  end

  before(:each) do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    
    allow_any_instance_of(ForestLiana::PermissionsChecker).to receive(:is_authorized?) { true }

    allow_any_instance_of(ForestLiana::ValueStatGetter).to receive(:perform) { true }
    allow_any_instance_of(ForestLiana::QueryStatGetter).to receive(:perform) { true }
  end



  describe 'POST /stats/:collection' do
    params = { type: 'Value', collection: 'User', aggregate: 'Count' }

    it 'should respond 200' do
      data = ForestLiana::Model::Stat.new(value: { countCurrent: 0, countPrevious: 0 })
      allow_any_instance_of(ForestLiana::ValueStatGetter).to receive(:record) { data }
      # NOTICE: bypass : find_resource error
      allow_any_instance_of(ForestLiana::StatsController).to receive(:find_resource) { true }
      allow(ForestLiana::QueryHelper).to receive(:get_one_association_names_symbol) { true }

      post '/forest/stats/Products', params: JSON.dump(params), headers: headers
      expect(response.status).to eq(200)
    end

    it 'should respond 401 with no headers' do
      post '/forest/stats/Products', params: JSON.dump(params)
      expect(response.status).to eq(401)
    end

    it 'should respond 404 with non existing collection' do
      allow_any_instance_of(ForestLiana::ValueStatGetter).to receive(:record) { nil }

      post '/forest/stats/NoCollection', params: {}, headers: headers
      expect(response.status).to eq(404)
    end

    it 'should respond 403 Forbidden' do
      allow_any_instance_of(ForestLiana::PermissionsChecker).to receive(:is_authorized?) { false }
      # NOTICE: bypass : find_resource error
      allow_any_instance_of(ForestLiana::StatsController).to receive(:find_resource) { true }

      post '/forest/stats/Products', params: JSON.dump(params), headers: headers
      expect(response.status).to eq(403)
    end
  end
  
  describe 'POST /stats' do
    params = { query: 'SELECT COUNT(*) AS value FROM products;' }

    it 'should respond 200' do
      data = ForestLiana::Model::Stat.new(value: { value: 0, objective: 0 })
      allow_any_instance_of(ForestLiana::QueryStatGetter).to receive(:record) { data }

      post '/forest/stats', params: JSON.dump(params), headers: headers
      expect(response.status).to eq(200)
    end

    it 'should respond 401 with no headers' do
      post '/forest/stats', params: JSON.dump(params)
      expect(response.status).to eq(401)
    end

    it 'should respond 403 Forbidden' do
      allow_any_instance_of(ForestLiana::PermissionsChecker).to receive(:is_authorized?) { false }

      post '/forest/stats', params: JSON.dump(params), headers: headers
      expect(response.status).to eq(403)
    end

    it 'should respond 422 with unprocessable query' do
      allow_any_instance_of(ForestLiana::QueryStatGetter).to receive(:perform) { raise ForestLiana::Errors::LiveQueryError.new }
      
      post '/forest/stats', params: JSON.dump(params), headers: headers
      expect(response.status).to eq(422)
    end
  end

end
