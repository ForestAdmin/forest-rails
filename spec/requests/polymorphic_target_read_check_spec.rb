require 'rails_helper'

# Rails does not require the targets of a polymorphic relation to declare an inverse, so a row may
# point at a model the relation's read check never covered.
describe 'Serving the target a polymorphic relation points at', type: :request do
  let(:auth_headers) do
    token = JWT.encode({ id: 1, email: 'michael.kelso@that70.show', first_name: 'Michael',
                         last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                         exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                       ForestLiana.auth_secret, 'HS256')
    { 'Accept' => 'application/json', 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
  end

  let(:readable) { %w[Address User] }
  let!(:user) { User.create!(name: 'Michel') }
  let!(:island) { Island.create!(name: 'Lemon Island') }
  let!(:to_user) { Address.create!(line1: '1 Palm Street', city: 'Papeete', zipcode: '98713', addressable: user) }
  let!(:to_island) { Address.create!(line1: '2 Palm Street', city: 'Papeete', zipcode: '98713', addressable: island) }

  before do
    Rails.cache.clear
    Rails.cache.write('forest.users', { '1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } })
    Rails.cache.write('forest.has_permission', true)
    enabled = { 'roles' => [1] }
    allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
      .with('/liana/v4/permissions/environment').and_return(
        'collections' => readable.to_h do |name|
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
    Rails.cache.clear
    Address.destroy_all
    Island.destroy_all
    User.destroy_all
  end

  def get_one(address)
    get "/forest/Address/#{address.id}",
        params: { fields: { 'Address' => 'id,line1,addressable', 'addressable' => 'id' }, timezone: 'Europe/Paris' },
        headers: auth_headers
    expect(response.status).to eq(200)
    JSON.parse(response.body)
  end

  def served_addressable(body)
    body['data'].dig('relationships', 'addressable', 'data')
  end

  def export_rows
    get '/forest/Address.csv',
        params: { fields: { 'Address' => 'id,addressable' }, header: 'id,addressable', timezone: 'Europe/Paris' },
        headers: auth_headers
    expect(response.status).to eq(200)
    response.body.lines.drop(1).map(&:strip)
  end

  it 'serves a target of a model the relation declares' do
    expect(served_addressable(get_one(to_user))).to include('type' => 'User', 'id' => user.id.to_s)
  end

  it 'withholds a target of a model the role cannot read, though the relation never declared it' do
    body = get_one(to_island)

    expect(served_addressable(body)).to be_nil
    expect(body.fetch('included', [])).to be_empty
  end

  context 'when the role reads that model' do
    let(:readable) { %w[Address User Island] }

    it 'serves the target' do
      expect(served_addressable(get_one(to_island))).to include('type' => 'Island', 'id' => island.id.to_s)
    end
  end

  context 'with skip_relation_read_permissions' do
    before { allow(ForestLiana).to receive(:skip_relation_read_permissions?).and_return(true) }

    it 'serves a target of any exposed model' do
      expect(served_addressable(get_one(to_island))).to include('type' => 'Island', 'id' => island.id.to_s)
    end
  end

  it 'leaves the cell of a withheld target empty in the CSV export' do
    expect(export_rows).to contain_exactly("#{to_user.id},#{user.id}", "#{to_island.id},")
  end

  # The rows of an export are serialized while the response streams, after the request cache is
  # gone: a permission asked for then could reach the Forest API mid-file.
  it 'answers the read permission of every model before the CSV export streams' do
    expect_any_instance_of(ForestLiana::ResourcesController).to receive(:read_permissions)
      .with(anything, array_including('Island', 'User')).and_call_original
    allow_any_instance_of(ForestLiana::ResourcesController).to receive(:read_permissions).and_call_original

    export_rows
  end

  it 'withholds the target rather than failing when its read permission is unavailable' do
    allow_any_instance_of(ForestLiana::ResourcesController).to receive(:readable_collection?)
      .and_raise(ForestLiana::Errors::PermissionsUnavailableError)

    expect(export_rows).to contain_exactly("#{to_user.id},", "#{to_island.id},")
  end
end
