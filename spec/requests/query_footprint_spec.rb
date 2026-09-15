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


    it 'joins the relation once and reads nothing per row' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
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

    it 'joins the same-database relation, never joins the other database, and reads it per row' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Product', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(join_count(result.grown, 'manufacturers')).to eq(1)
      expect(join_count(result.grown, 'drivers')).to eq(0)
      expect(selects_from(result.grown, 'manufacturers')).to be_empty
      expect(result.per_row_delta).to eq(1), -> { result.delta_report }
      expect(result.per_row_delta(table: 'drivers')).to eq(1), -> { result.delta_report(table: 'drivers') }

      sql = selects_from(result.grown, 'products').first
      expect(sql).to include(
        column_ref('products', 'name'), column_ref('products', 'driver_id'),
        column_ref('manufacturers', 'name')
      )
      expect(sql).not_to include(column_ref('products', 'uri'))
    end
  end

  describe 'a get-one' do
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


    it 'lists with one join and no per-row read' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(join_count(result.grown, 'users')).to eq(1)
    end

    it 'counts in one statement without a join it does not need' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree/count', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)['count']).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(selects_from(result.grown, 'trees').size).to eq(1)
      expect(join_count(result.grown, 'users')).to eq(0)
      expect(selects_from(result.grown, 'trees').first).to match(/COUNT\(/)
    end

    it 'still joins the count when the extended search only matches through the relation' do
      extended_params = params.merge(search: 'owner', searchExtended: '1')

      result = footprint(seed: seed) do |rows|
        get '/forest/Tree/count', params: extended_params, headers: headers
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)['count']).to eq(rows)
      end

      # Extended search always joins every has-one association (compute_includes falls
      # back to all of them once searchExtended is on, regardless of what was requested)
      # — owner and cutter both point at users, so the table is joined twice.
      expect(join_count(result.grown, 'users')).to eq(2)
      expect(selects_from(result.grown, 'trees').first).to match(/COUNT\(DISTINCT/)
    end

    it 'matches nothing on the same term when the search stays on the root column' do
      seed.call(3)

      get '/forest/Tree/count', params: params.merge(search: 'owner'), headers: headers

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['count']).to eq(0)
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


    it 'reads the whole relation in one query and narrows the root select to what was actually requested' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Owner', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      # Before: one SELECT per listed row, the getter's own `object.trees` walking the association
      # inside instance_eval (per-row delta 1, so 2 queries on 2 rows and 10 on 10). Now: one for
      # the whole page, keyed on the ids it already has (delta 0 — same count at 2 rows and at 10).
      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(result.per_row_delta(table: 'trees')).to eq(0), -> { result.delta_report(table: 'trees') }
      expect(selects_from(result.grown, 'trees').size).to eq(1)
      # A preload, never a join: joining a to-many into the root query would multiply its rows and
      # take LIMIT down with it.
      expect(join_count(result.grown, 'trees')).to eq(0)
      # `trees:name` still adds nothing to Owner's own select (a has_many keeps its key on the
      # target row); `name` is narrowed to because the request names it directly, same as any
      # other requested column.
      expect(selects_from(result.grown, 'owners').first).not_to include('"owners".*')
      expect(selects_from(result.grown, 'owners').first).to include(column_ref('owners', 'name'))
    end

    it 'serves the same values it did reading one row at a time' do
      seed.call(3)

      get '/forest/Owner', params: params, headers: headers

      expect(response).to have_http_status(200)
      names = JSON.parse(response.body)['data'].map { |row| row['attributes']['tree_names'] }
      expect(names).to all(eq('tree'))
    end
  end

  describe 'a list projecting a smart field walking a multi-hop relation path' do
    let(:seed) do
      lambda do |n|
        n.times do
          island = Island.create!(name: 'isle')
          Location.create!(island: island, coordinates: '0,0')
          Tree.create!(name: 'tree', island: island,
                       owner: User.create!(name: 'owner'), cutter: User.create!(name: 'cutter'))
        end
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,name,island_coordinates' }, page: page, searchExtended: '0',
        sort: '-id', timezone: 'Europe/Paris' }
    end

    # Island.table_name is 'isle', not 'islands'.
    it 'preloads every hop of the chain, one query per hop rather than per row' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(selects_from(result.grown, 'isle').size).to eq(1)
      expect(selects_from(result.grown, 'locations').size).to eq(1)
      expect(join_count(result.grown, 'isle')).to eq(0)
    end

    it 'reaches the far end of the chain' do
      seed.call(3)

      get '/forest/Tree', params: params, headers: headers

      expect(response).to have_http_status(200)
      coordinates = JSON.parse(response.body)['data'].map { |row| row['attributes']['island_coordinates'] }
      expect(coordinates).to all(eq('0,0'))
    end

    it 'leaves the chain alone entirely when the request never names the field' do
      other_params = params.merge(fields: { 'Tree' => 'id,name,owner_name_declared', 'owner' => 'name' })

      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: other_params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      # Tree declares island_coordinates (island:location:coordinates) too. Preloading it here
      # would trade this ticket's N+1 for a constant over-fetch of two relations nobody asked for.
      expect(selects_from(result.grown, 'isle')).to be_empty
      expect(selects_from(result.grown, 'locations')).to be_empty
      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
    end
  end

  describe 'a list projecting a smart field that walks an undeclared relation' do
    let(:seed) do
      lambda do |n|
        n.times { Location.create!(island: Island.create!(name: 'isle'), coordinates: '0,0') }
      end
    end
    let(:params) do
      { fields: { 'Location' => 'id,coordinates,island_name' }, page: page, searchExtended: '0',
        sort: '-id', timezone: 'Europe/Paris' }
    end

    # Location's smart fields declare nothing, so it is not projectable and island_name's own
    # `object.island` stays the lazy per-row read it has always been. Nothing in this ticket is
    # opt-out: the preload arrives with the declaration and never without it. Pinned so that
    # stays a choice rather than something a later change quietly takes away.
    it 'keeps its per-row read, and still serves the right value' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Location', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta(table: 'isle')).to eq(1), -> { result.delta_report(table: 'isle') }
      expect(JSON.parse(response.body)['data'].map { |row| row['attributes']['island_name'] })
        .to all(eq('isle'))
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


    it 'never joins the target, and batch-resolves it in one query on every supported Rails version' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Address', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(join_count(result.grown, 'users')).to eq(0)
      expect(selects_from(result.grown, 'addresses').size).to eq(1)

      # Before this fix: 1+N queries on Rails 6.1 (one per row, via each record's own belongs_to
      # lazy load), 1+1 from Rails 7 (BaseGetter#preload_polymorphic_associations's own branch,
      # unchanged here). Now 1+1 on every supported version - the batch loader no longer forks on
      # Rails::VERSION::MAJOR.
      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(selects_from(result.grown, 'users').size).to eq(1)
    end
  end

  describe 'a projected list with extended search, on a collection with a polymorphic relation the request never names' do
    let!(:resident) { User.create!(name: 'resident') }
    let!(:address) { Address.create!(line1: '1 Main St', city: 'Town', zipcode: '00000', addressable: resident) }

    after { Address.destroy_all; User.destroy_all }

    it "still selects the polymorphic association's own foreign_type, needed to preload it even though it was never requested" do
      params = { fields: { 'Address' => 'id,line1' }, page: page, searchExtended: '1', timezone: 'Europe/Paris' }

      get '/forest/Address', params: params, headers: headers

      expect(response).to have_http_status(200)
      expect(listed_rows).to eq(1)
    end
  end

  describe 'a related list projecting a smart field that walks a relation' do
    let!(:island) { Island.create!(name: 'isle') }
    let(:seed) do
      lambda do |n|
        n.times { Tree.create!(name: 'tree', island: island, owner: User.create!(name: 'owner')) }
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,name,owner_name_declared' }, page: page, searchExtended: '0',
        timezone: 'Europe/Paris' }
    end

    # The related list runs the same getters once per row as the main list does, through
    # HasManyGetter rather than ResourcesGetter — it needs the preload just as much, and gets it
    # whether or not it projects.
    it 'reads the relation once for the page, not once per row' do
      result = footprint(seed: seed) do |rows|
        get "/forest/Island/#{island.id}/relationships/trees", params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta(table: 'users')).to eq(0), -> { result.delta_report(table: 'users') }
      expect(selects_from(result.grown, 'users').size).to eq(1)
      expect(JSON.parse(response.body)['data'].map { |row| row['attributes']['owner_name_declared'] })
        .to all(eq('owner'))
    end
  end

  describe 'a list whose declared relation points at a model excluded from the schema' do
    before { ForestLiana.excluded_models = ['Island'] }

    after { ForestLiana.excluded_models = [] }

    # QueryHelper.get_one_associations drops an association whose target is not an exposed
    # collection, so the select built off it carries no island_id — and the preload then has no
    # key to read, failing the whole list with a missing-attribute error rather than the one
    # field. The foreign keys of a declared path are selected off the raw reflection for exactly
    # this reason.
    it 'still selects the foreign key its preload reads, and answers the list' do
      island = Island.create!(name: 'isle')
      Location.create!(island: island, coordinates: '0,0')
      Tree.create!(name: 'tree', island: island, owner: User.create!(name: 'owner'))

      get '/forest/Tree', params: { fields: { 'Tree' => 'id,name,island_coordinates' }, page: page,
                                    searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' },
          headers: headers

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['data'].first['attributes']['island_coordinates']).to eq('0,0')
    end
  end
end
