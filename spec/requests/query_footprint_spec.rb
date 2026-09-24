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

    it 'joins the same-database relation, never joins the other database, and reads it once' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Product', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(join_count(result.grown, 'manufacturers')).to eq(1)
      expect(join_count(result.grown, 'drivers')).to eq(0)
      expect(selects_from(result.grown, 'manufacturers')).to be_empty
      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(result.per_row_delta(table: 'drivers')).to eq(0), -> { result.delta_report(table: 'drivers') }
      expect(selects_from(result.grown, 'drivers').size).to eq(1)

      sql = selects_from(result.grown, 'products').first
      expect(sql).to include(
        column_ref('products', 'name'), column_ref('products', 'driver_id'),
        column_ref('manufacturers', 'name')
      )
      expect(sql).not_to include(column_ref('products', 'uri'))
    end

    it 'reads the other database in one statement keyed on the whole page' do
      seed.call(3)

      queries = capture_queries do
        get '/forest/Product', params: params, headers: headers
        expect(response).to have_http_status(200)
      end

      expect(selects_from(queries, 'drivers').size).to eq(1)
      expect(selects_from(queries, 'drivers').first).to match(/IN \(/i)
    end

    it 'serializes the same relation it served before it was preloaded' do
      seed.call(2)

      get '/forest/Product', params: params, headers: headers

      expect(response).to have_http_status(200)
      relationships = JSON.parse(response.body)['data'].map { |row| row['relationships']['driver']['data'] }
      expect(relationships.map { |data| data['type'] }).to all(eq('Driver'))
      expect(relationships.map { |data| data['id'] }).to match_array(Driver.pluck(:id).map(&:to_s))
    end

    it 'leaves a row whose cross-database key is null alone' do
      Product.create!(name: 'orphan', uri: 'https://example.test',
                      manufacturer: Manufacturer.create!(name: 'maker'), driver: nil)

      queries = capture_queries do
        get '/forest/Product', params: params, headers: headers
        expect(response).to have_http_status(200)
      end

      expect(selects_from(queries, 'drivers')).to be_empty
      expect(JSON.parse(response.body)['data'].first['relationships']['driver']['data']).to be_nil
    end

    it 'exports without reading the other database per row' do
      export_params = params.merge(header: 'id,name,manufacturer,driver', filename: 'products')

      result = footprint(seed: seed) do |rows|
        get '/forest/Product.csv', params: export_params, headers: headers
        expect(response).to have_http_status(200)
        expect(response.body.lines.size).to eq(rows + 1)
      end

      expect(result.per_row_delta(table: 'drivers')).to eq(0), -> { result.delta_report(table: 'drivers') }
    end
  end

  # A segment scope calling .select narrows @records before prepare_query returns, so
  # "@unprojected_records is unprojected" never meant "selects everything" — only that this class
  # did not narrow it. query_for_batch attaches its preload to that relation and find_in_batches
  # resolves it per batch, long after any record could be checked, so the guard reads the select.
  describe 'a list whose segment narrows the select' do
    let(:collection) { ForestLiana.apimap.find { |entry| entry.name.to_s == 'Product' } }
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
      { fields: { 'Product' => 'id,name,driver', 'driver' => 'firstname' }, page: page,
        segment: 'narrowed', searchExtended: '0', timezone: 'Europe/Paris' }
    end

    before do
      ForestLiana::BaseGetter.const_get(:PRELOAD_SKIPS_WARNED).clear
      collection.segments << ForestLiana::Model::Segment.new(name: 'narrowed', scope: :narrowed_select)
      allow(FOREST_LOGGER).to receive(:warn)
    end

    after { collection.segments.reject! { |segment| segment.name == 'narrowed' } }

    it 'exports the rows rather than failing on the key the segment left out' do
      seed.call(2)

      get '/forest/Product.csv',
          params: params.merge(header: 'id,name,driver', filename: 'products'), headers: headers

      expect(response).to have_http_status(200)
      expect(response.body.lines.size).to eq(3)
      expect(FOREST_LOGGER).to have_received(:warn)
        .with(a_string_including('"driver"', '"Product"', '"driver_id"', "query's select"))
    end

    it 'answers the list on the same segment' do
      seed.call(2)

      get '/forest/Product', params: params, headers: headers

      expect(response).to have_http_status(200)
      expect(listed_rows).to eq(2)
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

  describe 'a CSV export of a list projecting a smart field that walks a to-many relation' do
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
        sort: '-id', timezone: 'Europe/Paris', header: 'id,name,tree_names' }
    end

    it 'reads the whole relation in one query, not one per exported row' do
      result = footprint(seed: seed) do |_rows|
        get '/forest/Owner.csv', params: params, headers: headers
        expect(response).to have_http_status(200)
      end

      expect(result.per_row_delta(table: 'trees')).to eq(0), -> { result.delta_report(table: 'trees') }
      expect(selects_from(result.grown, 'trees').size).to eq(1)
    end
  end

  describe 'a list whose declared relation is keyed on something other than the primary key' do
    let(:seed) do
      lambda do |n|
        n.times do |index|
          owner = Owner.create!(name: "owner#{index}")
          Tree.create!(name: "owner#{index}", owner_id: owner.id)
        end
      end
    end
    let(:params) do
      # `name` is deliberately not requested: the only reason it can reach the select is that the
      # preload needs it as a key.
      { fields: { 'Owner' => 'id,tree_names_by_name' }, page: page, searchExtended: '0',
        sort: '-id', timezone: 'Europe/Paris' }
    end

    # The key preload reads off the owner row is the reflection's join_foreign_key, which for a
    # has_many is active_record_primary_key — `owners.name` here, the declared primary_key:, not
    # `owners.id`. Selecting the primary key alone answered the whole list with `missing
    # attribute: name`, HTTP 500: that error is raised resolving the query, where
    # MissingAttributeValve (a serialization-time valve) never sees it, so it took down every
    # field rather than the one that was under-declared.
    it 'selects the key its preload reads, and still reads the relation once for the page' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Owner', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta(table: 'trees')).to eq(0), -> { result.delta_report(table: 'trees') }
      expect(selects_from(result.grown, 'trees').size).to eq(1)
      expect(selects_from(result.grown, 'owners').first).to include(column_ref('owners', 'name'))
    end

    it 'matches each row with its own targets, not with the whole page' do
      seed.call(3)

      get '/forest/Owner', params: params, headers: headers

      expect(response).to have_http_status(200)
      values = JSON.parse(response.body)['data'].map { |row| row['attributes']['tree_names_by_name'] }
      expect(values).to match_array(%w[owner0 owner1 owner2])
    end
  end

  describe 'a list whose declared relation is a :through' do
    let(:seed) do
      lambda do |n|
        n.times do
          island = Island.create!(name: 'isle')
          Location.create!(island: island, coordinates: '0,0')
          Tree.create!(name: 'tree', island: island, owner: User.create!(name: 'owner'))
        end
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,through_coordinates' }, page: page, searchExtended: '0',
        sort: '-id', timezone: 'Europe/Paris' }
    end

    # `location` is a has_one :through :island, and a through preload starts by loading the hop it
    # goes through — reading `trees.island_id`, not the `trees.id` the outer reflection answers
    # for. Selecting the latter answered the whole list with `missing attribute: island_id`,
    # HTTP 500, for the same reason the primary-key case above did.
    it 'selects the key of the hop the preload starts with' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(selects_from(result.grown, 'locations').size).to eq(1)
    end

    it 'reaches the far end of the through' do
      seed.call(3)

      get '/forest/Tree', params: params, headers: headers

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['data'].map { |row| row['attributes']['through_coordinates'] })
        .to all(eq('0,0'))
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

  # PRD-1316. A relation the list also displays is built off the JOIN, with a select narrowed to
  # the requested columns — and the preloader leaves an already-loaded association alone, so the
  # next hop of the path reads its key off those narrowed rows. `users.name` was never selected:
  # the whole list answered 500 `missing attribute: name`, not just the field.
  #
  # The multi-hop fixture above never caught it because its own second hop (Island has_one
  # :location) keys on `isle.id`, and apply_column_aliases always emits a joined table's primary
  # key. Only a non-primary key reveals the gap.
  describe 'a list whose declared path goes through a relation the request also displays' do
    let(:seed) do
      seeded = 0
      lambda do |n|
        n.times do
          seeded += 1
          Tree.create!(name: "owner#{seeded}", owner: User.create!(name: "owner#{seeded}"))
        end
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,name,owner,owner_named_trees_count' }, page: page,
        searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    it 'selects the key the next hop reads off the joined row' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      # The key rides along in the JOIN's own select: still one joined query, never a second
      # SELECT on users and never a fallback to "users".*.
      expect(join_count(result.grown, 'users')).to eq(1)
      expect(selects_from(result.grown, 'users')).to be_empty
      root = selects_from(result.grown, 'trees').first
      expect(root).to include(column_ref('users', 'name'))
      expect(root).not_to include(column_ref('users', 'title'))
    end

    it 'selects it just as well when the request asks the relation for no column of its own' do
      seed.call(3)

      get '/forest/Tree', params: params.merge(fields: params[:fields].merge('owner' => 'id')),
          headers: headers

      expect(response).to have_http_status(200)
      counts = JSON.parse(response.body)['data'].map { |row| row['attributes']['owner_named_trees_count'] }
      expect(counts).to all(eq(1))
    end

    it 'reaches the far end of the path' do
      seed.call(3)

      get '/forest/Tree', params: params, headers: headers

      expect(response).to have_http_status(200)
      counts = JSON.parse(response.body)['data'].map { |row| row['attributes']['owner_named_trees_count'] }
      expect(counts).to all(eq(1))
    end
  end

  # The same shape declared the way the ticket declared it: the path names the :through relation
  # alone, and the relation the query joins (`owner`) is the hop it goes through — a hop the
  # declaration never mentions.
  describe 'a list whose declared :through hides the joined hop' do
    let(:seed) do
      seeded = 0
      lambda do |n|
        n.times do
          seeded += 1
          Tree.create!(name: "owner#{seeded}", owner: User.create!(name: "owner#{seeded}"))
        end
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,name,owner,owner_named_tree_names', 'owner' => 'id' }, page: page,
        searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    it 'selects the key the source hop reads off the joined through row' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(join_count(result.grown, 'users')).to eq(1)
      # As above: the key rides along in the JOIN's own select, and the narrowing survives —
      # giving up and selecting the whole joined row would serve the same page just as green.
      expect(selects_from(result.grown, 'users')).to be_empty
      root = selects_from(result.grown, 'trees').first
      expect(root).to include(column_ref('users', 'name'))
      expect(root).not_to include(column_ref('users', 'title'))
    end

    it 'reaches the far end of the through' do
      seed.call(3)

      get '/forest/Tree', params: params, headers: headers

      expect(response).to have_http_status(200)
      names = JSON.parse(response.body)['data'].map { |row| row['attributes']['owner_named_tree_names'] }
      expect(names).to all(match(/\Aowner\d+\z/))
    end
  end

  # PRD-1316, the half a fixture keyed on `name` cannot see: `join_foreign_key` is what the
  # preloader reads off the owner row, and `foreign_key` is not the same column. Both answer
  # `name` for User#trees_by_name, and every other hop of the suite where they differ keys on
  # `id`, which apply_column_aliases emits for a joined table anyway — so reading the wrong one
  # of the two costs nothing anywhere else, and the fix would be free to rot.
  #
  # User#trees_by_title holds them apart: `title` is read, `age` is the foreign key, and `age`
  # is no column of users at all, so the wrong one selects nothing and the list 500s again.
  describe 'a list whose joined hop is keyed on a column its foreign key is not' do
    let(:seed) do
      seeded = 0
      lambda do |n|
        n.times do
          seeded += 1
          Tree.create!(name: 'tree', owner: User.create!(name: "owner#{seeded}"))
        end
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,name,owner,owner_titled_trees_count', 'owner' => 'id' }, page: page,
        searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    it 'selects the key the preloader reads, not the association foreign key' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(join_count(result.grown, 'users')).to eq(1)
      expect(selects_from(result.grown, 'users')).to be_empty
      root = selects_from(result.grown, 'trees').first
      expect(root).to include(column_ref('users', 'title'))
      expect(root).not_to include(column_ref('users', 'name'))
    end
  end

  # The path does not stop at the displayed relation but carries on past it. The preloader leaves
  # that whole declaration alone — it is already loaded off the JOIN — so the hop *after* it reads
  # its key off those narrowed rows. Where the relation is a :through, the hop the chain starts
  # with (`island`) is not the one the request displays (`location`), and looking only at the
  # first named nothing as joined at all: 500 on `locations.coordinates`.
  describe 'a list whose declared path carries on past a joined :through' do
    let(:seed) do
      seeded = 0
      lambda do |n|
        n.times do
          seeded += 1
          island = Island.create!(name: "isle#{seeded}")
          Location.create!(island: island, coordinates: "tree#{seeded}")
          Tree.create!(name: "tree#{seeded}", island: island, owner: User.create!(name: 'owner'))
        end
      end
    end
    let(:params) do
      { fields: { 'Tree' => 'id,name,location,location_trees_count', 'location' => 'id' },
        page: page, searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    it 'selects the key the hop after the whole declaration reads' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Tree', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      # Rails 6.1's Preloader reuses the association the JOIN already loaded and the page costs
      # nothing extra. From Rails 7 it re-walks the :through instead — only `location` is loaded
      # on these rows, never the `island` it goes through — and builds Locations of its own that
      # `object.location`, still the JOIN's row, never reads: the preload is wasted and the field
      # falls back to one read per row. Orthogonal to the key selected here, which is what makes
      # that read answer the right thing rather than nothing; pinned so it stays visible.
      expect(result.per_row_delta(table: 'trees')).to eq(Rails::VERSION::MAJOR >= 7 ? 1 : 0),
                                                      -> { result.delta_report(table: 'trees') }
      # The key rides along in the JOIN's own select, which stays narrowed: still one joined
      # query, and never a fallback to "locations".*.
      expect(join_count(result.grown, 'locations')).to eq(1)
      root = selects_from(result.grown, 'trees').first
      expect(root).to include(column_ref('locations', 'coordinates'))
      expect(root).not_to include(column_ref('locations', 'updated_at'))
    end

    it 'reaches the far end of the path' do
      seed.call(3)

      get '/forest/Tree', params: params, headers: headers

      expect(response).to have_http_status(200)
      counts = JSON.parse(response.body)['data'].map { |row| row['attributes']['location_trees_count'] }
      expect(counts).to all(eq(1))
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

  # On Car rather than Product, which the dummy declares countable: false — its count route
  # short-circuits before building a query at all, and would guard nothing.
  describe 'a count on a collection with a cross-database relation' do
    let(:seed) do
      lambda do |n|
        n.times { Car.create!(model: 'coupe', driver: Driver.create!(firstname: 'pilot')) }
      end
    end
    let(:params) do
      { fields: { 'Car' => 'id,model,driver', 'driver' => 'firstname' }, page: page,
        searchExtended: '0', timezone: 'Europe/Paris' }
    end

    # count and query_for_batch read the same @unprojected_records, so the count must not inherit
    # a preload it has no page to run for.
    it 'counts in one statement, without reading the other database' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Car/count', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)['count']).to eq(rows)
      end

      expect(result.per_row_delta).to eq(0), -> { result.delta_report }
      expect(selects_from(result.grown, 'cars').size).to eq(1)
      expect(selects_from(result.grown, 'drivers')).to be_empty
    end

    it 'still preloads the other database once on the list itself' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Car', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta(table: 'drivers')).to eq(0), -> { result.delta_report(table: 'drivers') }
      expect(selects_from(result.grown, 'drivers').size).to eq(1)
    end
  end

  # serializer_factory intercepts this shape with a find_by of its own, which ran per row and
  # undid the preload.
  describe 'a list projecting a cross-database relation keyed on a custom primary_key' do
    let(:seed) do
      lambda do |n|
        n.times do |i|
          Driver.create!(firstname: "pilot-#{i}")
          Car.create!(model: "pilot-#{i}", driver: Driver.create!(firstname: 'other'))
        end
      end
    end
    let(:params) do
      { fields: { 'Car' => 'id,model,pilot', 'pilot' => 'firstname' }, page: page,
        searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    it 'reads the other database once for the page, not once per row' do
      result = footprint(seed: seed) do |rows|
        get '/forest/Car', params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(result.per_row_delta(table: 'drivers')).to eq(0), -> { result.delta_report(table: 'drivers') }
      expect(selects_from(result.grown, 'drivers').size).to eq(1)
    end

    it 'serializes the same relation the per-row find_by resolved' do
      seed.call(2)

      get '/forest/Car', params: params, headers: headers

      expect(response).to have_http_status(200)
      body = JSON.parse(response.body)
      linkage = body['data'].map { |row| [row['id'], row['relationships']['pilot']['data']] }
      # What the per-row find_by this branch replaces would have resolved, row by row.
      expected = body['data'].map do |row|
        car = Car.find(row['id'])
        [row['id'], Driver.find_by(firstname: car.model)&.id&.to_s]
      end

      expect(linkage.map { |id, data| [id, data && data['id']] }).to eq(expected)
      expect(linkage.map { |_, data| data['type'] }).to all(eq('Driver'))
    end

    it 'still resolves a row whose key matches nothing' do
      Car.create!(model: 'nobody', driver: Driver.create!(firstname: 'other'))

      get '/forest/Car', params: params, headers: headers

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['data'].first['relationships']['pilot']['data']).to be_nil
    end
  end

  # The has_one half, which the guard used to wave through by only looking at a belongs_to:
  # unguarded, the list answered 500 on a key nothing projects.
  describe 'a list projecting a cross-database has_one keyed on a custom primary_key' do
    let(:seed) do
      lambda do |n|
        n.times do |i|
          driver = Driver.create!(firstname: "pilot-#{i}")
          Car.create!(model: driver.firstname, driver: driver)
        end
      end
    end
    let(:params) do
      { fields: { 'Driver' => 'id,piloted_car', 'piloted_car' => 'id' }, page: page,
        searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' }
    end

    it 'answers the list rather than failing on the key the projection left out' do
      seed.call(2)

      get '/forest/Driver', params: params, headers: headers

      expect(response).to have_http_status(200)
      expect(listed_rows).to eq(2)
    end

    # Not what the fallback serves: MissingAttributeValve already resolved it up to Rails 7.0 and
    # served null from 7.1, before any of this. Pinned here is that the guard stands aside.
    it 'preloads it in one statement once the key is projected' do
      seed.call(2)
      projected = params.deep_merge(fields: { 'Driver' => 'id,firstname,piloted_car' })

      queries = capture_queries do
        get '/forest/Driver', params: projected, headers: headers
        expect(response).to have_http_status(200)
      end

      expect(selects_from(queries, 'cars').size).to eq(1)
      expect(selects_from(queries, 'cars').first).to match(/IN \(/i)

      linkage = JSON.parse(response.body)['data'].map do |row|
        [row['id'], row['relationships']['piloted_car']['data']&.fetch('id')]
      end
      expected = linkage.map { |id, _| [id, Car.find_by(model: Driver.find(id).firstname)&.id&.to_s] }

      expect(linkage).to eq(expected)
      expect(linkage.map { |_, car_id| car_id }).to all(be_present)
    end

    # Scoped to this message: the fallback legitimately raises MissingAttributeValve's too.
    it 'says once per process why it fell back to the load it replaces' do
      ForestLiana::BaseGetter.const_get(:PRELOAD_SKIPS_WARNED).clear
      seed.call(2)
      warnings = []
      allow(FOREST_LOGGER).to receive(:warn) { |message| warnings << message }

      2.times { get '/forest/Driver', params: params, headers: headers }

      expect(response).to have_http_status(200)
      skipped = warnings.grep(/cannot be preloaded/)
      expect(skipped.size).to eq(1)
      expect(skipped.first).to include('"piloted_car"', '"Driver"', '"firstname"', 'another database')
    end
  end

  describe 'a related list projecting a cross-database relation' do
    let!(:manufacturer) { Manufacturer.create!(name: 'maker') }
    let(:seed) do
      lambda do |n|
        n.times do
          Product.create!(name: 'thing', uri: 'https://example.test', manufacturer: manufacturer,
                          driver: Driver.create!(firstname: 'pilot'))
        end
      end
    end
    let(:params) do
      { fields: { 'Product' => 'id,name,driver', 'driver' => 'firstname' }, page: page,
        searchExtended: '0', timezone: 'Europe/Paris' }
    end

    # HasManyGetter preloads preload_loads from Rails 7 on, so this only ever read per row on 6.1,
    # for a limitation that was never about another database.
    it 'reads the other database once for the page on every supported Rails' do
      result = footprint(seed: seed) do |rows|
        get "/forest/Manufacturer/#{manufacturer.id}/relationships/products",
            params: params, headers: headers
        expect(response).to have_http_status(200)
        expect(listed_rows).to eq(rows)
      end

      expect(join_count(result.grown, 'drivers')).to eq(0)
      expect(result.per_row_delta(table: 'drivers')).to eq(0), -> { result.delta_report(table: 'drivers') }
      expect(selects_from(result.grown, 'drivers').size).to eq(1)
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

    # Same exclusion, reached the other way: `location` is a has_one :through whose hop is the
    # excluded Island, and it is requested as a field rather than declared as a dependency. The
    # through walk resolves its hops off the raw reflection for the same reason the select above
    # does — get_one_association drops the excluded model, and the walk then ran onto nil.
    it 'walks a requested has_one :through whose hop is excluded, instead of failing the list' do
      island = Island.create!(name: 'isle')
      Location.create!(island: island, coordinates: '0,0')
      Tree.create!(name: 'tree', island: island, owner: User.create!(name: 'owner'))

      get '/forest/Tree', params: { fields: { 'Tree' => 'id,name,location', 'location' => 'coordinates' },
                                    page: page, searchExtended: '0', sort: '-id', timezone: 'Europe/Paris' },
          headers: headers

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['included'].first['attributes']['coordinates']).to eq('0,0')
    end
  end
end
