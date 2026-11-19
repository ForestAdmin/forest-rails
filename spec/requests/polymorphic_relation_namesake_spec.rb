require 'rails_helper'

# PRD-2267: a polymorphic relation was given the targets of every namesake on another owner, so a
# role reading its real targets still saw it refused.
describe 'A polymorphic relation sharing its name with another owner\'s', type: :request do
  token = JWT.encode({ id: 1, email: 'michael.kelso@that70.show', first_name: 'Michael',
                       last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                       exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                     ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }

  let!(:user) { User.create!(name: 'Michel') }
  let!(:address) { Address.create!(line1: '1 Palm Street', city: 'Papeete', zipcode: '98713', addressable: user) }
  let(:namesakes) do
    [
      stub_const('PolyNote', Class.new(ActiveRecord::Base) do
        self.table_name = 'articles'
        belongs_to :addressable, polymorphic: true
      end),
      stub_const('PolyHarbor', Class.new(ActiveRecord::Base) do
        self.table_name = 'harbors'
        has_many :poly_notes, as: :addressable
      end)
    ]
  end

  before do
    ForestLiana.models.push(*namesakes)

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

    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return('scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' })
  end

  after do
    namesakes.each { |model| ForestLiana.models.delete(model) }
    Address.destroy_all
    User.destroy_all
  end

  it 'serves the relation to a role that reads its own targets' do
    get "/forest/Address/#{address.id}",
        params: { fields: { 'Address' => 'id,line1,addressable', 'addressable' => 'id' }, timezone: 'Europe/Paris' },
        headers: headers

    expect(response.status).to eq(200)
    relationship = JSON.parse(response.body)['data']['relationships']['addressable']
    expect(relationship['data']).to include('id' => user.id.to_s)
  end

  it 'keeps the relation column in the CSV export' do
    get '/forest/Address.csv',
        params: { fields: { 'Address' => 'id,line1,addressable', 'addressable' => 'id' },
                  header: 'id,line1,addressable', timezone: 'Europe/Paris' },
        headers: headers

    expect(response.status).to eq(200)
    expect(response.body.lines.first.strip).to eq('id,line1,addressable')
  end

  it 'exports the id of the target, as the list shows it, when no field of the target is named' do
    get '/forest/Address.csv',
        params: { fields: { 'Address' => 'id,line1,addressable' },
                  header: 'id,line1,addressable', timezone: 'Europe/Paris' },
        headers: headers

    expect(response.status).to eq(200)
    expect(response.body.lines.second.strip).to eq("#{address.id},1 Palm Street,#{user.id}")
  end

  it 'still exports the named field of the target' do
    get '/forest/Address.csv',
        params: { fields: { 'Address' => 'id,line1,addressable', 'addressable' => 'name' },
                  header: 'id,line1,addressable', timezone: 'Europe/Paris' },
        headers: headers

    expect(response.status).to eq(200)
    expect(response.body.lines.second.strip).to eq("#{address.id},1 Palm Street,Michel")
  end
end
