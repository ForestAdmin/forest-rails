require 'rails_helper'

describe 'Requesting Owner', :type => :request  do
  before(:each) do
    Owner.destroy_all

    1.upto(10) do |i|
      owner = Owner.create(name: "Owner #{i}")
      Tree.create(name: "Tree #{i}", owner_id: owner.id)
    end

    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }

    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }

    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return({'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}})
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
      get '/forest/Owner/5/relationships/trees/count', params: params, headers: headers
      expect(response.status).to eq(200)
    end

    it 'should equal to 1' do
      get '/forest/Owner/5/relationships/trees/count', params: params, headers: headers
      expect(response.body).to eq('{"count":1}')
    end
  end

  describe 'count on an unknown relationship' do
    params = {
      fields: { 'Tree' => 'id,name,owner' },
      page: { 'number' => '1', 'size' => '10' },
      searchExtended: '0',
      timezone: 'Europe/Paris'
    }

    it 'should respond 404 instead of 500' do
      get '/forest/Owner/5/relationships/unknown_things/count', params: params, headers: headers
      expect(response.status).to eq(404)
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

describe 'Requesting Tree count with extended search', :type => :request do
  let(:scope_filters) { { 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } } }

  # NOTICE: `Kiwi Tree` matches the search on its own column, `Lemon Tree` matches
  #         only through `owner.name`, and `Apple Tree` matches nothing. Extended
  #         search must therefore return 2 records, plain search 1.
  before(:each) do
    Tree.destroy_all
    Location.destroy_all
    Island.destroy_all
    User.destroy_all

    michel = User.create(name: 'Michel')
    kiwi_grower = User.create(name: 'Kiwi Grower')
    @island = Island.create(name: 'Home Island')

    Tree.create(name: 'Kiwi Tree', owner: michel, cutter: michel, island: @island)
    Tree.create(name: 'Lemon Tree', owner: kiwi_grower, cutter: michel, island: @island)
    Tree.create(name: 'Apple Tree', owner: michel, cutter: michel, island: @island)

    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }

    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }

    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scope_filters)
  end

  after(:each) do
    Tree.destroy_all
    Location.destroy_all
    Island.destroy_all
    User.destroy_all
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

  def count_returned
    JSON.parse(response.body)['count']
  end

  def records_returned
    JSON.parse(response.body)['data'].size
  end

  describe 'count' do
    let(:projection) { { 'Tree' => 'id,name,owner' } }
    let(:params) {
      {
        page: { 'number' => '1', 'size' => '10' },
        search: 'kiwi',
        searchExtended: '1',
        timezone: 'Europe/Paris'
      }
    }

    describe 'when the request carries no fields' do
      it 'responds 200 with the number of records the list returns for the same search' do
        get '/forest/Tree', params: params, headers: headers
        listed = records_returned

        get '/forest/Tree/count', params: params, headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(2)
        expect(count_returned).to eq(listed)
      end
    end

    describe 'when the request carries fields' do
      it 'responds 200 with the number of records the list returns for the same search' do
        get '/forest/Tree', params: params.merge(fields: projection), headers: headers
        listed = records_returned

        get '/forest/Tree/count', params: params.merge(fields: projection), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(2)
        expect(count_returned).to eq(listed)
      end
    end

    describe 'when the same count is requested twice' do
      it 'returns the same count both times' do
        get '/forest/Tree/count', params: params, headers: headers
        first_count = count_returned

        get '/forest/Tree/count', params: params, headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(2)
        expect(count_returned).to eq(first_count)
      end
    end

    describe 'when extended search is off' do
      it 'counts only the records matching on their own columns' do
        get '/forest/Tree', params: params.merge(searchExtended: '0'), headers: headers
        listed = records_returned

        get '/forest/Tree/count', params: params.merge(searchExtended: '0'), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(1)
        expect(count_returned).to eq(listed)
      end
    end

    describe 'when searchExtended is absent from the request' do
      it 'counts only the records matching on their own columns' do
        get '/forest/Tree/count', params: params.except(:searchExtended), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(1)
      end
    end

    describe 'when the search matches no record at all' do
      it 'responds 200 with a count of zero' do
        get '/forest/Tree', params: params.merge(search: 'sequoia'), headers: headers
        listed = records_returned

        get '/forest/Tree/count', params: params.merge(search: 'sequoia'), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(0)
        expect(count_returned).to eq(listed)
      end
    end

    describe 'when the search is an empty string' do
      it 'counts every record' do
        get '/forest/Tree/count', params: params.merge(search: ''), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(3)
      end
    end

    describe 'when the request carries no search at all' do
      it 'counts every record' do
        get '/forest/Tree/count', params: params.except(:search), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(3)
      end
    end
  end

  describe 'count on relationships' do
    let(:projection) { { 'Tree' => 'id,name' } }
    let(:params) {
      {
        page: { 'number' => '1', 'size' => '10' },
        search: 'kiwi',
        searchExtended: '1',
        timezone: 'Europe/Paris'
      }
    }

    describe 'when the count carries no fields and the list carries the projection' do
      it 'counts the number of records the related list returns' do
        get "/forest/Island/#{@island.id}/relationships/trees",
            params: params.merge(fields: projection), headers: headers
        listed = records_returned

        get "/forest/Island/#{@island.id}/relationships/trees/count", params: params, headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(2)
        expect(count_returned).to eq(listed)
      end
    end

    describe 'when both the count and the list carry the projection' do
      it 'counts the number of records the related list returns' do
        get "/forest/Island/#{@island.id}/relationships/trees",
            params: params.merge(fields: projection), headers: headers
        listed = records_returned

        get "/forest/Island/#{@island.id}/relationships/trees/count",
            params: params.merge(fields: projection), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(2)
        expect(count_returned).to eq(listed)
      end
    end

    describe 'when extended search is off' do
      it 'counts only the related records matching on their own columns' do
        get "/forest/Island/#{@island.id}/relationships/trees",
            params: params.merge(searchExtended: '0', fields: projection), headers: headers
        listed = records_returned

        get "/forest/Island/#{@island.id}/relationships/trees/count",
            params: params.merge(searchExtended: '0'), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(1)
        expect(count_returned).to eq(listed)
      end
    end

    describe 'when the related search matches no record at all' do
      it 'responds 200 with a count of zero' do
        get "/forest/Island/#{@island.id}/relationships/trees/count",
            params: params.merge(search: 'sequoia'), headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(0)
      end
    end

    describe 'when the parent record has no related record' do
      it 'responds 200 with a count of zero' do
        empty_island = Island.create(name: 'Empty Island')

        get "/forest/Island/#{empty_island.id}/relationships/trees/count", params: params, headers: headers

        expect(response.status).to eq(200)
        expect(count_returned).to eq(0)
      end
    end
  end
end
