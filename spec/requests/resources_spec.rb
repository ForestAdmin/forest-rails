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

  headers = {
    'Accept' => 'application/json',
    'Content-Type' => 'application/json',
    'Authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJleHAiOiIxODQ5ODc4ODYzIiwiZGF0YSI6eyJpZCI6IjM4IiwidHlwZSI6InVzZXJzIiwiZGF0YSI6eyJlbWFpbCI6Im1pY2hhZWwua2Vsc29AdGhhdDcwLnNob3ciLCJmaXJzdF9uYW1lIjoiTWljaGFlbCIsImxhc3RfbmFtZSI6IktlbHNvIiwidGVhbXMiOiJPcGVyYXRpb25zIn0sInJlbGF0aW9uc2hpcHMiOnsicmVuZGVyaW5ncyI6eyJkYXRhIjpbeyJ0eXBlIjoicmVuZGVyaW5ncyIsImlkIjoxNn1dfX19fQ.U4Mxi0tq0Ce7y5FRXP47McNPRPhUx37LznQ5E3mJIp4'
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
