require 'rails_helper'

describe 'Schema scans of a list call', type: :request do
  token = JWT.encode({ id: 38, email: 'michael.kelso@that70.show', first_name: 'Michael',
                       last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                       exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                     ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }

  let(:auth_headers) { headers }
  let!(:user) { User.create!(name: 'Michel') }
  let!(:address) { Address.create!(line1: '1 Palm Street', city: 'Papeete', zipcode: '98713', addressable: user) }

  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    Rails.cache.write('forest.has_permission', false)
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return({ 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } })
  end

  after do
    Address.destroy_all
    User.destroy_all
  end

  def list(fields)
    get '/forest/Address', params: { fields: fields, page: { 'number' => '1', 'size' => '10' },
                                     sort: '-id', timezone: 'Europe/Paris' }, headers: auth_headers
    expect(response).to have_http_status(200)
  end

  it 'scans the models for the targets of a polymorphic relation once, whatever the projection' do
    scans = 0
    allow(ForestLiana::SchemaUtils).to receive(:scan_polymorphic_models).and_wrap_original do |original, *args|
      scans += 1
      original.call(*args)
    end

    list('Address' => 'id,line1')
    list('Address' => 'id,line1,city,zipcode,addressable', 'addressable' => 'id')

    expect(scans).to eq(1)
  end

  it 'reflects on the serialized model once, whatever the number of rows' do
    2.times { Address.create!(line1: 'Another street', city: 'Papeete', zipcode: '98713', addressable: user) }
    scans = []
    allow(ForestLiana::SchemaUtils).to receive(:scan_associations).and_wrap_original do |original, model|
      scans << model
      original.call(model)
    end

    list('Address' => 'id,line1,addressable', 'addressable' => 'id')

    expect(JSON.parse(response.body)['data'].size).to eq(3)
    expect(scans.count(Address)).to eq(1)
  end
end
