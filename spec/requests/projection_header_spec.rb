require 'rails_helper'

describe 'Requesting resources with the Forest-Projection header', :type => :request do
  before(:each) do
    Address.destroy_all
    Tree.destroy_all
    Island.destroy_all
    User.destroy_all

    @user = User.create(name: 'Michel', title: :king)
    @island = Island.create(name: 'Lemon Island')
    @tree = Tree.create(name: 'Lemon Tree', age: 12, owner: @user, cutter: @user, island: @island)
    @address = Address.create(line1: '1 Palm Street', city: 'Papeete', zipcode: '98713', addressable: @user)

    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
    allow_any_instance_of(ForestLiana::Ability).to receive(:forest_authorize!) { true }
    allow(ForestLiana::ScopeManager).to receive(:fetch_scopes)
      .and_return({ 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } })
  end

  let(:auth_headers) do
    token = JWT.encode({
      id: 1,
      email: 'michael.kelso@that70.show',
      first_name: 'Michael',
      last_name: 'Kelso',
      team: 'Operations',
      rendering_id: 16,
      exp: Time.now.to_i + 2.weeks.to_i,
      permission_level: 'admin'
    }, ForestLiana.auth_secret, 'HS256')

    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  def projecting(projection)
    auth_headers.merge('Forest-Projection' => projection)
  end

  let(:list_params) do
    {
      page: { 'number' => '1', 'size' => '10' },
      searchExtended: '0',
      sort: '-id',
      timezone: 'Europe/Paris'
    }
  end

  # The projection has to reach the SQL layer, otherwise the over-fetch simply moved one
  # layer down: the serialized output would be projected while every column is still read.
  def selects_of(table)
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      queries << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:cached]
    end

    begin
      yield
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    queries.select { |query| query.start_with?('SELECT') && query.include?(%("#{table}")) }
      .join("\n")
  end

  def body
    JSON.parse(response.body)
  end

  describe 'on the list' do
    it 'serializes the projected fields only' do
      get '/forest/Tree', params: list_params, headers: projecting('id,name')

      expect(response.status).to eq 200
      expect(body['data'].first['attributes']).to eq('id' => @tree.id, 'name' => 'Lemon Tree')
    end

    it 'selects the projected columns only' do
      selected = selects_of('trees') do
        get '/forest/Tree', params: list_params, headers: projecting('id,name,owner:name')
      end

      expect(selected).to include('"trees"."name"')
      expect(selected).to include('"users"."name"')
      expect(selected).not_to include('"trees"."age"')
      expect(selected).not_to include('"users"."title"')
    end

    it 'projects several fields on the same relation' do
      get '/forest/Tree', params: list_params, headers: projecting('id,name,owner:name,owner:title')

      included = body['included'].find { |record| record['type'] == 'User' }
      expect(included['attributes']).to eq('name' => 'Michel', 'title' => 'king')
    end

    it 'wins over the fields query params' do
      selected = selects_of('trees') do
        get '/forest/Tree',
          params: list_params.merge(fields: { 'Tree' => 'id,name,age' }),
          headers: projecting('id,name')
      end

      expect(body['data'].first['attributes']).to eq('id' => @tree.id, 'name' => 'Lemon Tree')
      expect(selected).not_to include('"trees"."age"')
    end

    it 'leaves the fields query params alone when the header is absent' do
      get '/forest/Tree', params: list_params.merge(fields: { 'Tree' => 'id,age' }), headers: auth_headers

      expect(body['data'].first['attributes']).to eq('id' => @tree.id, 'age' => 12)
    end
  end

  describe 'on get-one' do
    it 'serializes the projected fields only' do
      get "/forest/Tree/#{@tree.id}", headers: projecting('id,name,owner:name')

      expect(response.status).to eq 200
      expect(body['data']['attributes']).to eq('id' => @tree.id, 'name' => 'Lemon Tree')
      expect(body['included'].map { |record| record['type'] }).to eq ['User']
      expect(body['included'].first['attributes']).to eq('name' => 'Michel')
    end

    it 'selects the projected columns only' do
      selected = selects_of('trees') do
        get "/forest/Tree/#{@tree.id}", headers: projecting('id,name,owner:name')
      end

      expect(selected).to include('"trees"."name"')
      expect(selected).to include('"users"."name"')
      expect(selected).not_to include('"trees"."age"')
      expect(selected).not_to include('"users"."title"')
    end

    it 'joins the projected relations only' do
      selected = selects_of('trees') do
        get "/forest/Tree/#{@tree.id}", headers: projecting('id,name,owner:name')
      end

      expect(selected).not_to include('"isle"')
    end

    it 'projects a collection carrying no relation at all' do
      selected = selects_of('users') do
        get "/forest/User/#{@user.id}", headers: projecting('id,name')
      end

      expect(response.status).to eq 200
      expect(body['data']['attributes']).to eq('id' => @user.id, 'name' => 'Michel')
      expect(selected).to include('"users"."name"')
      expect(selected).not_to include('"users"."title"')
      expect(selected).not_to include('_forest_admin_eager_load')
    end

    # NOTICE: Computing a Smart Field may read any column of the record, so a projection naming
    #         one is dropped rather than starving it, exactly as the list already does.
    it 'reads every column when the projection names a Smart Field' do
      allow(ForestLiana::SchemaHelper).to receive(:is_smart_field?).and_call_original
      allow(ForestLiana::SchemaHelper).to receive(:is_smart_field?).with(User, 'cap_name').and_return(true)

      selected = selects_of('users') do
        get "/forest/User/#{@user.id}", headers: projecting('id,name,cap_name')
      end

      expect(response.status).to eq 200
      expect(body['data']['attributes']).to include('name' => 'Michel')
      expect(selected).to include('"users".*')
    end

    it 'serializes the whole record when the header is absent' do
      get "/forest/Tree/#{@tree.id}", headers: auth_headers

      expect(body['data']['attributes'].keys).to include('id', 'name', 'age')
    end
  end

  # NOTICE: A scope filtering on a relation makes FiltersParser eager load it, on a query the
  #         projection has already been applied to. The projection has to be decided after the
  #         scopes: deciding before leaves the select without the _forest_admin_eager_load
  #         marker, and the record without the foreign key that join reads.
  describe 'on get-one under a scope filtering on a relation' do
    before(:each) do
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(
        'scopes' => {
          'Tree' => {
            'aggregator' => 'and',
            'conditions' => [{ 'field' => 'owner:name', 'operator' => 'equal', 'value' => 'Michel' }]
          }
        },
        'team' => { 'id' => '1', 'name' => 'Operations' }
      )
    end

    it 'answers the projected record when the projection names no relation' do
      get "/forest/Tree/#{@tree.id}", headers: projecting('id,name')

      expect(response.status).to eq 200
      expect(body['data']['attributes']).to eq('id' => @tree.id, 'name' => 'Lemon Tree')
    end

    it 'reads the columns the projection names and the key the scope joins on' do
      selected = selects_of('trees') do
        get "/forest/Tree/#{@tree.id}", headers: projecting('id,name')
      end

      expect(response.status).to eq 200
      expect(selected).to include('"trees"."name"')
      expect(selected).to include('"trees"."owner_id"')
      expect(selected).not_to include('"trees"."age"')
    end

    it 'answers the projected record when the projection names the scoped relation' do
      get "/forest/Tree/#{@tree.id}", headers: projecting('id,name,owner:name')

      expect(response.status).to eq 200
      expect(body['data']['attributes']).to eq('id' => @tree.id, 'name' => 'Lemon Tree')
      expect(body['included'].first['attributes']).to eq('name' => 'Michel')
    end
  end

  describe 'on a relationship list' do
    it 'roots the projection on the association target' do
      get "/forest/Island/#{@island.id}/relationships/trees",
        params: list_params,
        headers: projecting('id,name,owner:name')

      expect(response.status).to eq 200
      expect(body['data'].first['attributes']).to eq('id' => @tree.id, 'name' => 'Lemon Tree')
      expect(body['included'].find { |record| record['type'] == 'User' }['attributes'])
        .to eq('name' => 'Michel')
    end

    # NOTICE: This route preloads the relations it displays instead of joining them, to keep
    #         LIMIT off a row-multiplied join (see HasManyGetter#optimize_record_loading). The
    #         projection narrows the columns of the collection itself; a displayed relation is
    #         still read whole by its own preload, and only the serialization projects it.
    it 'selects the projected columns of the collection itself' do
      selected = selects_of('trees') do
        get "/forest/Island/#{@island.id}/relationships/trees",
          params: list_params,
          headers: projecting('id,name,owner:name')
      end

      expect(selected).to include('"trees"."name"')
      expect(selected).to include('"trees"."owner_id"')
      expect(selected).not_to include('"trees"."age"')
      expect(selected).not_to include('JOIN "users"')
    end
  end

  # NOTICE: A path ending on a polymorphic relation carries no discriminant, so its targets are
  #         loaded one by one out of the main query. The path is accepted and the relation is
  #         fetched, but its own fields cannot be honoured: the serializer keys a projection by
  #         collection name and a polymorphic target has several, so the target comes back whole.
  #         Rejecting the path instead would break every list holding a polymorphic column.
  describe 'on a path crossing a polymorphic relation' do
    it 'projects the root and fetches the target whole on the list' do
      get '/forest/Address', params: list_params, headers: projecting('id,line1,addressable:name')

      expect(response.status).to eq 200
      expect(body['data'].first['attributes']).to eq('id' => @address.id, 'line1' => '1 Palm Street')
      expect(body['data'].first['relationships']['addressable']['data'])
        .to eq('type' => 'User', 'id' => @user.id.to_s)
      expect(body['included'].first['attributes']).to include('name' => 'Michel')
    end

    it 'reads the discriminant on get-one, not the columns it did not ask for' do
      selected = selects_of('addresses') do
        get "/forest/Address/#{@address.id}", headers: projecting('id,line1,addressable:name')
      end

      expect(response.status).to eq 200
      expect(body['data']['attributes']).to eq('id' => @address.id, 'line1' => '1 Palm Street')
      expect(body['included'].first['attributes']).to include('name' => 'Michel')
      expect(selected).to include('"addresses"."addressable_type"')
      expect(selected).to include('"addresses"."addressable_id"')
      expect(selected).not_to include('"addresses"."city"')
    end
  end

  describe 'on a CSV export' do
    it 'honours the header, like the fields query params' do
      get '/forest/Tree.csv',
        params: list_params.merge(header: 'id,name'),
        headers: projecting('id,name')

      expect(response.status).to eq 200
      expect(response.body.split("\n")).to eq ['id,name', "#{@tree.id},Lemon Tree"]
    end
  end

  describe 'when the header is malformed' do
    it 'answers a 400 naming the offending path on the list' do
      get '/forest/Tree', params: list_params, headers: projecting('id,island:location:coordinates')

      expect(response.status).to eq 400
      expect(body['errors'].first['detail'])
        .to include('the path "island:location:coordinates" traverses more than one relation')
    end

    it 'answers a 400 on get-one' do
      get "/forest/Tree/#{@tree.id}", headers: projecting('id,,name')

      expect(response.status).to eq 400
      expect(body['errors'].first['detail']).to include('it holds an empty path')
    end

    it 'answers a 400 on a relationship list' do
      get "/forest/User/#{@user.id}/relationships/trees_owned",
        params: list_params,
        headers: projecting('id,island:')

      expect(response.status).to eq 400
      expect(body['errors'].first['detail']).to include(%(the path "island:" names no field after ":"))
    end

    # NOTICE: Falling back to the full projection would make an agent that does not understand
    #         the header answer exactly like one that does.
    it 'does not fall back to the full projection' do
      get '/forest/Tree', params: list_params.merge(fields: { 'Tree' => 'id,name' }), headers: projecting('')

      expect(response.status).to eq 400
      expect(body['errors'].first['detail']).to include('it is empty')
    end
  end

  # NOTICE: A name the collection does not hold is dropped, the way the fields query params
  #         already drop it. It used to reach the SQL as a column and answer a 500 — the list
  #         never showed it because its eager load hands the select list to the JoinDependency,
  #         which quietly discards what matches no joined table.
  describe 'on a projection naming something the collection does not hold' do
    it 'drops an unknown field on get-one' do
      selected = selects_of('trees') do
        get "/forest/Tree/#{@tree.id}", headers: projecting('id,does_not_exist')
      end

      expect(response.status).to eq 200
      expect(body['data']['attributes']).to eq('id' => @tree.id)
      expect(selected).not_to include('does_not_exist')
    end

    it 'drops an unknown field on a relationship list' do
      get "/forest/Island/#{@island.id}/relationships/trees",
        params: list_params,
        headers: projecting('id,does_not_exist')

      expect(response.status).to eq 200
      expect(body['data'].first['attributes']).to eq('id' => @tree.id)
    end

    it 'drops an unknown field on a relation' do
      selected = selects_of('users') do
        get "/forest/Tree/#{@tree.id}", headers: projecting('id,owner:name,owner:does_not_exist')
      end

      expect(response.status).to eq 200
      expect(selected).to include('"users"."name"')
      expect(selected).not_to include('does_not_exist')
    end

    # NOTICE: The header feeds the select list, so anything but a real column name reaching it
    #         would carry whatever text the caller wrote straight into the SQL.
    it 'keeps a header naming SQL out of the select list' do
      selected = selects_of('trees') do
        get "/forest/Tree/#{@tree.id}", headers: projecting('id,name FROM users--')
      end

      expect(response.status).to eq 200
      expect(selected).not_to include('users')
      expect(selected).not_to include('--')
    end
  end

  # NOTICE: A belongs_to carries its foreign key on the owner row, a has_one on the target row,
  #         and the target table is only in the FROM clause when the query joins it.
  describe 'on a projection naming a has_one' do
    it 'reads the foreign key from the target table when the query joins it' do
      selected = selects_of('locations') do
        get "/forest/Island/#{@island.id}", headers: projecting('id,name,location:id')
      end

      expect(response.status).to eq 200
      expect(selected).to include('"locations"."island_id"')
      expect(selected).not_to include('"isle"."island_id"')
    end

    # NOTICE: An instance dependent scope cannot be joined, so the relation is read by a query of
    #         its own and the owner select needs nothing for it — its primary key already covers
    #         the link.
    it 'names no foreign key for a relation the query does not join' do
      selected = selects_of('isle') do
        get "/forest/Island/#{@island.id}", headers: projecting('id,name,eponymous_tree')
      end

      expect(response.status).to eq 200
      expect(selected).to include('"isle"."name"')
      expect(selected).not_to include('island_id')
    end
  end

  # NOTICE: Only a bare column name can be table-qualified. An ordering expression would reach
  #         the SQL as table.LOWER(name) and raise.
  describe 'on a collection ordered by an expression' do
    around(:each) do |example|
      previous = Owner.default_scopes
      Owner.default_scopes = []
      Owner.send(:default_scope) { order(Arel.sql('LOWER(name) ASC')) }
      example.run
      Owner.default_scopes = previous
    end

    it 'leaves the ordering expression out of the select' do
      getter = ForestLiana::ResourceGetter.new(
        Owner, ActionController::Parameters.new(id: 1, fields: { 'Owner' => 'id,name' }), nil
      )

      expect(getter.send(:compute_select_fields, [])).to eq(
        ['_forest_admin_eager_load', 'owners.id', 'owners.name']
      )
    end
  end
end
