require 'rails_helper'

describe 'Exporting a belongsTo to CSV', type: :request do
  let(:auth_headers) do
    token = JWT.encode({ id: 1, email: 'michael.kelso@that70.show', first_name: 'Michael',
                         last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                         exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                       ForestLiana.auth_secret, 'HS256')
    { 'Accept' => 'application/json', 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{token}" }
  end

  let!(:owner) { User.create!(name: 'Michel') }
  let!(:tree) { Tree.create!(name: 'Lemon Tree', owner: owner, cutter: owner) }

  before do
    Rails.cache.clear
    Rails.cache.write('forest.users', { '1' => { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } })
    Rails.cache.write('forest.has_permission', true)
    enabled = { 'roles' => [1] }
    allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
      .with('/liana/v4/permissions/environment').and_return(
        'collections' => %w[Tree User].to_h do |name|
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
    Tree.destroy_all
    User.destroy_all
  end

  def export(owner_fields)
    get '/forest/Tree.csv',
        params: { fields: { 'Tree' => 'id,name,owner', 'owner' => owner_fields },
                  header: 'id,name,owner', timezone: 'Europe/Paris' },
        headers: auth_headers

    expect(response.status).to eq(200)
    response.body.lines.second.strip
  end

  it 'exports the reference field of the target' do
    expect(export('name')).to eq("#{tree.id},Lemon Tree,Michel")
  end

  # A basic segment condition on another sub-field of the relation adds it after the reference field.
  it 'exports the reference field when the front also names other sub-fields' do
    expect(export('name,title')).to eq("#{tree.id},Lemon Tree,Michel")
  end
end
