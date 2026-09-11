require 'rails_helper'

describe 'SQL footprint of a front call', type: :request do
  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    # forest_authorize! is bypassed above, so the field-read guards it would otherwise gate must be
    # too, or they call the permissions API through the file-backed cache another file last wrote.
    Rails.cache.write('forest.has_permission', false)
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return({ 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } })
  end

  token = JWT.encode({ id: 38, email: 'michael.kelso@that70.show', first_name: 'Michael',
                        last_name: 'Kelso', team: 'Operations', rendering_id: 16,
                        exp: Time.now.to_i + 2.weeks.to_i, permission_level: 'admin' },
                      ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }
  page = { 'number' => '1', 'size' => '10' }

  def listed_rows
    JSON.parse(response.body)['data'].size
  end

  describe 'a list projecting a to-one relation' do
    let(:seed) do
      lambda do |n|
        n.times do
          user = User.create!(name: 'owner')
          Tree.create!(name: 'tree', owner: user, cutter: user)
        end
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,name,owner', 'owner' => 'name' }, page: page,
        searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    after { Tree.destroy_all; User.destroy_all }

    it 'joins the relation once and reads nothing per row' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0)
      expect(selects_from(result.grown, 'trees').size).to eq(1)
      expect(join_count(result.grown, 'users')).to eq(1)
      expect(selects_from(result.grown, 'users')).to be_empty

      sql = selects_from(result.grown, 'trees').first
      expect(sql).to include(column_ref('trees', 'name'), column_ref('users', 'name'))
      expect(sql).not_to include(column_ref('trees', 'age'), column_ref('users', 'title'))
    end
  end

  describe 'a list projecting a cross-database relation' do
    let(:seed) do
      lambda do |n|
        n.times do
          Product.create!(name: 'thing', uri: 'https://example.test',
                           manufacturer: Manufacturer.create!(name: 'maker'),
                           driver: Driver.create!(firstname: 'pilot'))
        end
      end
    end
    let(:params) do
      { fields: { 'Product' => 'id,name,manufacturer,driver', 'manufacturer' => 'name',
                  'driver' => 'firstname' },
        page: page, searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    after { Product.destroy_all; Manufacturer.destroy_all; Driver.destroy_all }

    it 'joins the same-database relation, never joins the other database, and reads it per row' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Product', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(join_count(result.grown, 'manufacturers')).to eq(1)
      expect(join_count(result.grown, 'drivers')).to eq(0)
      expect(selects_from(result.grown, 'manufacturers')).to be_empty
      expect(result.per_row_delta).to eq(1)
      expect(result.per_row_delta(table: 'drivers')).to eq(1)

      sql = selects_from(result.grown, 'products').first
      expect(sql).to include(
        column_ref('products', 'name'), column_ref('products', 'driver_id'),
        column_ref('manufacturers', 'name')
      )
      expect(sql).not_to include(column_ref('products', 'uri'))
    end
  end

  describe 'a get-one' do
    after { Product.destroy_all; Manufacturer.destroy_all; Driver.destroy_all }

    it 'joins the same-database relation, reads the cross-database one once and loads every column' do
      manufacturer = Manufacturer.create!(name: 'maker')
      driver = Driver.create!(firstname: 'pilot')
      product = Product.create!(name: 'thing', uri: 'https://example.test',
                                 manufacturer: manufacturer, driver: driver)

      queries = capture_queries do
        get "/forest/Product/#{product.id}", params: { timezone: 'Europe/Paris' }, headers: headers
        expect(response).to have_http_status(200)
      end

      expect(selects_from(queries, 'products').size).to eq(1)
      expect(join_count(queries, 'manufacturers')).to eq(1)
      expect(join_count(queries, 'drivers')).to eq(0)
      expect(selects_from(queries, 'manufacturers')).to be_empty
      expect(selects_from(queries, 'drivers').size).to eq(1)
      expect(selects_from(queries, 'products').first).to include(column_ref('products', 'uri'))
    end
  end

  describe 'a searched list and its count' do
    let(:seed) do
      lambda do |n|
        n.times do
          user = User.create!(name: 'owner')
          Tree.create!(name: 'tree', owner: user, cutter: user)
        end
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,name,owner', 'owner' => 'name' }, search: 'tree',
        searchExtended: '0', page: page, sort: '-id', timezone: 'Europe/Paris' }
    end

    after { Tree.destroy_all; User.destroy_all }

    it 'lists with one join and no per-row read' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0)
      expect(join_count(result.grown, 'users')).to eq(1)
    end

    it 'counts in one statement that still joins the projected relation' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree/count', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)['count']).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0)
      expect(selects_from(result.grown, 'trees').size).to eq(1)
      expect(join_count(result.grown, 'users')).to eq(1)
      expect(selects_from(result.grown, 'trees').first).to match(/COUNT\(DISTINCT/)
    end
  end

  describe 'a list projecting a smart field that walks a to-many relation' do
    let(:seed) do
      lambda do |n|
        n.times do
          owner = Owner.create!(name: 'owner')
          Tree.create!(name: 'tree', owner_id: owner.id)
        end
      end
    end
    let(:params) do
      { fields: { 'Owner' => 'id,name,tree_names' }, page: page, searchExtended: '0',
        sort: '-id', timezone: 'Europe/Paris' }
    end

    after { Tree.destroy_all; Owner.destroy_all }

    it 'reads the relation once per row and loads every column of the root' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Owner', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(1)
      expect(result.per_row_delta(table: 'trees')).to eq(1)
      expect(join_count(result.grown, 'trees')).to eq(0)
      expect(selects_from(result.grown, 'owners').first).to include('"owners".*')
    end
  end

  describe 'a list projecting a polymorphic relation' do
    let(:seed) do
      lambda do |n|
        n.times do
          user = User.create!(name: 'resident')
          Address.create!(line1: '1 Main St', city: 'Town', zipcode: '00000', addressable: user)
        end
      end
    end
    let(:params) do
      { fields: { 'Address' => 'id,line1,addressable', 'addressable' => 'name' }, page: page,
        searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    after { Address.destroy_all; User.destroy_all }

    it 'never joins the target and resolves it per row on Rails 6, in one batch from Rails 7' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Address', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(join_count(result.grown, 'users')).to eq(0)
      expect(selects_from(result.grown, 'addresses').size).to eq(1)

      # The batch loader for polymorphic targets in ResourcesGetter#records is gated on Rails 7,
      # mirroring the same version fork the production code makes (resources_getter.rb).
      if Rails.gem_version >= Gem::Version.new('7.0')
        expect(result.per_row_delta).to eq(0)
        expect(selects_from(result.grown, 'users').size).to eq(1)
      else
        expect(result.per_row_delta).to eq(1)
        expect(result.per_row_delta(table: 'users')).to eq(1)
      end
    end
  end
end
