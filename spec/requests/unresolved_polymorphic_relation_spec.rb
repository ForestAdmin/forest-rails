require 'rails_helper'

# devise_invitable declares `belongs_to :invited_by, polymorphic: true` with no `as: :invited_by`
# inverse anywhere, so no target can be resolved for it (#824).
describe 'A polymorphic relation with no declared target', type: :request do
  token = JWT.encode({ id: 1, email: 'michael.kelso@that70.show', first_name: 'Michael',
                       last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                       exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                     ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }

  let!(:user) { User.create!(name: 'Michel') }
  let!(:address) { Address.create!(line1: '1 Palm Street', city: 'Papeete', zipcode: '98713', addressable: user) }

  before do
    Rails.cache.clear
    Rails.cache.write('forest.users', { '1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } })
    Rails.cache.write('forest.has_permission', true)
    enabled = { 'roles' => [1] }
    allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
      .with('/liana/v4/permissions/environment').and_return(
        'collections' => %w[Address User].to_h do |name|
          [name, { 'collection' => %w[browseEnabled readEnabled editEnabled addEnabled deleteEnabled exportEnabled]
                                     .to_h { |key| [key, enabled] }, 'actions' => {} }]
        end
      )
    allow(ForestLiana::SchemaUtils).to receive(:polymorphic_models).and_call_original
    allow(ForestLiana::SchemaUtils).to receive(:polymorphic_models)
      .with(Address.reflect_on_association(:addressable)).and_return([])

    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return('scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' })
  end

  after do
    Address.destroy_all
    User.destroy_all
  end

  it 'serves the get-one without the relation instead of refusing it' do
    get "/forest/Address/#{address.id}",
        params: { fields: { 'Address' => 'id,line1,addressable', 'addressable' => 'id' }, timezone: 'Europe/Paris' },
        headers: headers

    expect(response.status).to eq(200)
    body = JSON.parse(response.body)
    expect(body['data']['attributes']['line1']).to eq('1 Palm Street')
    expect(body['data'].fetch('relationships', {})).not_to have_key('addressable')
  end

  it 'still refuses a sort on the relation' do
    get '/forest/Address',
        params: { fields: { 'Address' => 'id,line1' }, sort: 'addressable.id', page: { 'number' => '1', 'size' => '10' },
                  timezone: 'Europe/Paris' },
        headers: headers

    expect(response.status).to eq(403)
  end
end
