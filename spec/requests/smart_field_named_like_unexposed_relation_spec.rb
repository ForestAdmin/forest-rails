require 'rails_helper'

# Forest::Boat#harbor and Forest::Captain#license share their name with a relation of the model.
# With the relation's target left out of the apimap, SchemaAdapter drops the relation and only the
# smart field remains: the request reads it off the root row, not off the unexposed target.
describe 'A computed smart field named like a relation to an unexposed collection', type: :request do
  token = JWT.encode({ id: 38, email: 'michael.kelso@that70.show', first_name: 'Michael',
                       last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                       exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                     ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }
  page = { 'number' => '1', 'size' => '15' }

  let!(:harbor) { Harbor.create!(name: 'Saint-Malo') }
  let!(:captain) { Captain.create!(name: 'Haddock', license_number: 'FR-4421') }
  let!(:license) { License.create!(number: 'FR-4421', expires_on: Date.new(2030, 1, 1)) }
  let!(:boat) { Boat.create!(name: 'Karaboudjan', harbor: harbor, captain: captain) }

  let(:unexposed) { [] }

  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return('scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' })
    allow(ForestLiana).to receive(:apimap).and_wrap_original do |original|
      original.call.reject { |collection| unexposed.include?(collection.name.to_s) }
    end
    # The apimap was built at boot with every target exposed: drop the relations to the unexposed
    # ones, as SchemaAdapter does for a model left out of it.
    ForestLiana.apimap.each do |collection|
      allow(collection).to receive(:fields).and_wrap_original do |original|
        original.call.reject { |field| unexposed.include?(field[:reference].to_s.split('.').first) }
      end
    end
  end

  def body
    JSON.parse(response.body)
  end

  shared_examples 'serving the smart field off the root' do
    context 'when the belongs_to target is unexposed' do
      let(:unexposed) { ['Harbor'] }

      it 'serves the list' do
        get '/forest/Boat', params: { fields: { 'Boat' => 'id,name,harbor' }, page: page, timezone: 'Europe/Paris' },
                            headers: headers

        expect(response.status).to eq(200)
        expect(body['data'].map { |row| row['attributes']['harbor'] }).to eq(['Saint-Malo'])
      end

      it 'serves the get-one' do
        get "/forest/Boat/#{boat.id}", params: { fields: { 'Boat' => 'id,name,harbor' }, timezone: 'Europe/Paris' },
                                       headers: headers

        expect(response.status).to eq(200)
        expect(body['data']['attributes']['harbor']).to eq('Saint-Malo')
      end
    end

    context 'when the has_one target is unexposed' do
      let(:unexposed) { ['License'] }

      it 'serves the list' do
        get '/forest/Captain', params: { fields: { 'Captain' => 'id,name,license' }, page: page, timezone: 'Europe/Paris' },
                               headers: headers

        expect(response.status).to eq(200)
        expect(body['data'].map { |row| row['attributes']['license'] }).to eq(['FR-4421'])
      end

      it 'serves the get-one' do
        get "/forest/Captain/#{captain.id}", params: { fields: { 'Captain' => 'id,name,license' }, timezone: 'Europe/Paris' },
                                             headers: headers

        expect(response.status).to eq(200)
        expect(body['data']['attributes']['license']).to eq('FR-4421')
      end
    end
  end

  context 'with skip_relation_read_permissions, as Qonto runs it' do
    before do
      allow(ForestLiana).to receive(:skip_relation_read_permissions?) { true }
      Rails.cache.write('forest.has_permission', true)
    end

    include_examples 'serving the smart field off the root'
  end

  context 'without a permission system' do
    before { Rails.cache.write('forest.has_permission', false) }

    include_examples 'serving the smart field off the root'
  end
end
