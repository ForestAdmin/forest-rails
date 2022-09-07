require 'rails_helper'

describe 'Requesting Owner', :type => :request  do
  before(:each) do
    1.upto(10) do |i|
      owner = Owner.create(name: "Owner #{i}")
      Tree.create(name: "Tree #{i}", owner_id: owner.id)
    end
  end

  after(:each) do
    Owner.destroy_all
  end

  before(:each) do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }

    allow_any_instance_of(ForestLiana::PermissionsChecker).to receive(:is_authorized?) { true }

    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return({})
  end

  token = JWT.encode({
                       id: 38,
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
  describe 'count' do
    params = {
      fields: { 'Owner' => 'id,name' },
      page: { 'number' => '1', 'size' => '10' },
      searchExtended: '0',
      sort: '-id',
      timezone: 'Europe/Paris'
    }

    it 'should respond 200' do
      get '/forest/Owner/count', params: params, headers: headers
      expect(response.status).to eq(200)
    end

    it 'should equal to 10' do
      get '/forest/Owner/count', params: params, headers: headers
      expect(response.body).to eq('{"count":10}')
    end
  end

  describe 'count on relationships' do
    params = {
      fields: { 'Tree' => 'id,name,owner' },
      page: { 'number' => '1', 'size' => '10' },
      searchExtended: '0',
      sort: '-id',
      timezone: 'Europe/Paris'
    }

    it 'should respond 200' do
      get '/forest/Owner/1/relationships/trees/count', params: params, headers: headers
      expect(response.status).to eq(200)
    end

    it 'should equal to 1' do
      get '/forest/Owner/1/relationships/trees/count', params: params, headers: headers
      expect(response.body).to eq('{"count":1}')
    end
  end

  describe 'deactivate_count_response' do
    params = {
      fields: { 'Owner' => 'id,name' },
      page: { 'number' => '1', 'size' => '10' },
      search: 'foo',
      searchExtended: '0',
      sort: '-id',
      timezone: 'Europe/Paris'
    }

    it 'should respond 200' do
      get '/forest/Owner/count', params: params, headers: headers
      expect(response.status).to eq(200)
    end

    it 'should equal to deactivated response' do
      get '/forest/Owner/count', params: params, headers: headers
      expect(response.body).to eq('{"meta":{"count":"deactivated"}}')
    end
  end

  describe 'deactivate_count_response' do
    params = {
      fields: { 'Tree' => 'id,name,owner' },
      page: { 'number' => '1', 'size' => '10' },
      search: 'foo',
      searchExtended: '0',
      sort: '-id',
      timezone: 'Europe/Paris'
    }

    it 'should respond 200' do
      get '/forest/Owner/1/relationships/trees/count', params: params, headers: headers
      expect(response.status).to eq(200)
    end

    it 'should equal to deactivated response' do
      get '/forest/Owner/1/relationships/trees/count', params: params, headers: headers
      expect(response.body).to eq('{"meta":{"count":"deactivated"}}')
    end
  end
end
