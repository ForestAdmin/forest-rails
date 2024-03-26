require 'rails_helper'
require 'json'

describe "Stats", type: :request do
  let(:rendering_id) { '13' }
  let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
  let(:schema) {
    [
      ForestLiana::Model::Collection.new({
                                           name: 'Product',
                                           fields: [],
                                           actions: []
                                         })
    ]
  }

  let(:token) {
      JWT.encode({
      id: 1,
      email: 'michael.kelso@that70.show',
      first_name: 'Michael',
      last_name: 'Kelso',
      team: 'Operations',
      rendering_id: rendering_id,
      exp: Time.now.to_i + 2.weeks.to_i,
      permission_level: 'user'
    }, ForestLiana.auth_secret, 'HS256')
  }

  let(:headers) {
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  }

  before do
    Rails.cache.write('forest.users', {'1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' }})
    Rails.cache.write('forest.has_permission', true)
    allow_any_instance_of(ForestLiana::Ability::Permission)
      .to receive(:get_permissions)
        .and_return(
          {
            "stats" => [
              {
                "type" => "Value",
                "filter" => nil,
                "aggregator" => "Count",
                "aggregateFieldName" => nil,
                "sourceCollectionName" => "Owner"
              },
              {
                "type" => "Objective",
                "sourceCollectionName" => "Owner",
                "aggregateFieldName" => nil,
                "aggregator" => "Count",
                "objective" => 200,
                "filter" => nil,
              },
              {
                "type" => "Pie",
                "sourceCollectionName" => "Owner",
                "aggregateFieldName" => nil,
                "groupByFieldName" => "id",
                "aggregator" => "Count",
                "filter" => nil,
              },
              {
                "type" => "Line",
                "sourceCollectionName" => "Owner",
                "aggregateFieldName" => nil,
                "groupByFieldName" => "hired_at",
                "aggregator" => "Count",
                "timeRange" => "Week",
                "filter" => nil,
              },
              {
                "type"  => "Value",
                "query" => "SELECT COUNT(*) AS value FROM products;"
              }
            ],
          }
        )

    ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)

    allow(ForestLiana).to receive(:apimap).and_return(schema)
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
  end

  describe 'POST /stats/:collection' do
    params = { type: 'Value', collection: 'Owner', aggregator: 'Count', sourceCollectionName: 'Owner', aggregateFieldName: nil, filter: nil}
    it 'should respond 200' do
      Rails.cache.delete('forest.stats')
      post '/forest/stats/Owner', params: JSON.dump(params), headers: headers

      expect(response.status).to eq(200)
    end

    it 'should respond 200 with Objective chart' do
      Rails.cache.delete('forest.stats')
      params = {type: "Objective", sourceCollectionName: "Owner", aggregateFieldName: nil, aggregator: "Count", objective: 200, filter: nil, contextVariables: {}}
      post '/forest/stats/Owner', params: JSON.dump(params), headers: headers

      expect(response.status).to eq(200)
    end

    it 'should respond 200 with Pie chart' do
      Rails.cache.delete('forest.stats')
      params = { type: "Pie", sourceCollectionName: "Owner", aggregateFieldName: nil, groupByFieldName: "id", aggregator: "Count", filter: nil, contextVariables:nil }
      post '/forest/stats/Owner', params: JSON.dump(params), headers: headers

      expect(response.status).to eq(200)
    end

    it 'should respond 200 with Line chart' do
      Rails.cache.delete('forest.stats')
      params = { type: "Line", sourceCollectionName: "Owner", aggregateFieldName: nil, groupByFieldName: "hired_at", aggregator: "Count", timeRange: "Week", filter: nil, contextVariables:nil }
      post '/forest/stats/Owner', params: JSON.dump(params), headers: headers

      expect(response.status).to eq(200)
    end

    it 'should respond 403 Forbidden' do
      no_admin_token = JWT.encode({
                                    id: 1,
                                    email: 'michael.kelso@that70.show',
                                    first_name: 'Michael',
                                    last_name: 'Kelso',
                                    team: 'Operations',
                                    rendering_id: '1',
                                    exp: Time.now.to_i + 2.weeks.to_i,
                                    permission_level: 'user'
                                  }, ForestLiana.auth_secret, 'HS256')

      no_admin_headers = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{no_admin_token}"
      }

      params[:aggregateFieldName] = 'foo'
      Rails.cache.delete('forest.stats')
      allow_any_instance_of(ForestLiana::StatsController).to receive(:find_resource).and_return(Product)
      data = ForestLiana::Model::Stat.new(value: { countCurrent: 0, countPrevious: 0 })
      allow_any_instance_of(ForestLiana::ValueStatGetter).to receive(:record) { data }
      # NOTICE: bypass : find_resource error
      allow_any_instance_of(ForestLiana::StatsController).to receive(:find_resource) { true }
      allow(ForestLiana::QueryHelper).to receive(:get_one_association_names_symbol) { true }


      post '/forest/stats/Products', params: JSON.dump(params), headers: no_admin_headers

      expect(response.status).to eq(403)
    end
  end

  describe 'POST /stats' do
    params = { type: 'Value', query: 'SELECT COUNT(*) AS value FROM products;' }

    it 'should respond 200' do
      allow_any_instance_of(ForestLiana::StatsController).to receive(:find_resource).and_return(Product)
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
      no_admin_token = JWT.encode({
                                    id: 1,
                                    email: 'michael.kelso@that70.show',
                                    first_name: 'Michael',
                                    last_name: 'Kelso',
                                    team: 'Operations',
                                    rendering_id: '16',
                                    exp: Time.now.to_i + 2.weeks.to_i,
                                    permission_level: 'user'
                                  }, ForestLiana.auth_secret, 'HS256')

      no_admin_headers = {
        'Accept' => 'application/json',
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{no_admin_token}"
      }
      params[:query] = 'SELECT COUNT(*) AS value FROM trees;'
      Rails.cache.delete('forest.stats')
      allow_any_instance_of(ForestLiana::StatsController).to receive(:find_resource).and_return(Product)

      post '/forest/stats', params: JSON.dump(params), headers: no_admin_headers
      expect(response.status).to eq(403)
    end
  end
end
