require 'rails_helper'
require 'json'

describe 'Capabilities', type: :request do
  let(:token) do
    JWT.encode(
      {
        id: 1,
        email: 'michael.kelso@that70.show',
        first_name: 'Michael',
        last_name: 'Kelso',
        team: 'Operations',
        rendering_id: '13',
        exp: Time.now.to_i + 2.weeks.to_i,
        permission_level: 'admin'
      },
      ForestLiana.auth_secret,
      'HS256'
    )
  end
  let(:headers) do
    {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  before do
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
  end

  def fetch_capabilities(collection_names)
    post '/forest/_internal/capabilities',
      params: { collectionNames: collection_names }.to_json,
      headers: headers

    JSON.parse(response.body)
  end

  def field(body, collection_name, field_name)
    collection = body['collections'].find { |item| item['name'] == collection_name }
    collection['fields'].find { |item| item['name'] == field_name }
  end

  describe 'authentication' do
    it 'rejects a call without a token' do
      post '/forest/_internal/capabilities',
        params: { collectionNames: ['Tree'] }.to_json,
        headers: headers.except('Authorization')

      expect(response.status).to eq(401)
    end
  end

  describe 'requested collections' do
    it 'answers only the requested ones' do
      body = fetch_capabilities(['Tree'])

      expect(response.status).to eq(200)
      expect(body['collections'].map { |collection| collection['name'] }).to eq(['Tree'])
    end

    it 'ignores an unknown collection name' do
      body = fetch_capabilities(['Tree', 'ThisCollectionDoesNotExist'])

      expect(response.status).to eq(200)
      expect(body['collections'].map { |collection| collection['name'] }).to eq(['Tree'])
    end

    it 'answers no collection when none is requested' do
      body = fetch_capabilities([])

      expect(response.status).to eq(200)
      expect(body['collections']).to eq([])
    end
  end

  describe 'agentCapabilities' do
    # NOTICE: This liana implements none of the announced behaviours yet; each flag flips
    #         in the ticket that implements it.
    it 'announces every flag as false' do
      body = fetch_capabilities(['Tree'])

      expect(body['agentCapabilities']).to eq(
        'canUseProjectionOnGetOne' => false,
        'canUseProjectionViaHeader' => false,
        'canUseProjectionViaHeaderOnList' => false,
        'canUseMultipleFieldsProjectionOnRelation' => false,
        'canUseAuditTrail' => false
      )
    end
  end

  describe 'nativeQueryConnections' do
    # NOTICE: Announcing connections would make the frontend send live queries to
    #         /_internal/native_query, which this liana does not serve.
    it 'is not announced at all' do
      body = fetch_capabilities(['Tree'])

      expect(body).not_to have_key('nativeQueryConnections')
    end
  end

  describe 'fields' do
    it 'announces a column with the operators the liana implements' do
      body = fetch_capabilities(['Tree'])

      expect(field(body, 'Tree', 'name')).to eq(
        'name' => 'name',
        'type' => 'String',
        'operators' => %w(
          equal not_equal present blank in
          starts_with ends_with contains i_contains not_contains
        ),
        'isGroupable' => true
      )
      expect(field(body, 'Tree', 'age')['operators'])
        .to eq(%w(equal not_equal present blank in greater_than less_than))
      expect(field(body, 'Tree', 'created_at')['operators'])
        .to include('previous_quarter_to_date', 'before_x_hours_ago')
    end

    it 'announces a belongsTo as a ManyToOne groupable off its foreign key column' do
      body = fetch_capabilities(['Tree'])

      expect(field(body, 'Tree', 'owner')).to eq(
        'name' => 'owner',
        'type' => 'ManyToOne',
        'isGroupable' => true
      )
    end

    it 'leaves out the relationships that carry no capability' do
      body = fetch_capabilities(['Tree'])

      expect(field(body, 'Tree', 'location')).to be_nil
    end

    it 'announces a polymorphic relation without claiming it is groupable' do
      body = fetch_capabilities(['Address'])

      expect(field(body, 'Address', 'addressable')).to eq(
        'name' => 'addressable',
        'type' => 'ManyToOne',
        'isGroupable' => false
      )
    end

    # NOTICE: Both columns behind the relation are declared with polymorphic_key, and neither
    #         groups on its own — the foreign key needs its type column to mean anything.
    it 'announces the columns behind it as not groupable either' do
      body = fetch_capabilities(['Address'])

      expect(field(body, 'Address', 'addressable_id')['isGroupable']).to eq(false)
      expect(field(body, 'Address', 'addressable_type')['isGroupable']).to eq(false)
    end

    # NOTICE: Field#isGroupable returns false on a primary key before it reads the announcement,
    #         so claiming true here would only inflate supportGroups.
    it 'announces the primary key as not groupable' do
      body = fetch_capabilities(['Tree'])

      expect(field(body, 'Tree', 'id')).to eq(
        'name' => 'id',
        'type' => 'Number',
        'operators' => %w(equal not_equal present blank in greater_than less_than),
        'isGroupable' => false
      )
    end

    it 'announces no operator on a field the liana cannot filter' do
      body = fetch_capabilities(['Address'])

      expect(field(body, 'Address', 'address_type')).to eq(
        'name' => 'address_type',
        'type' => 'String',
        'operators' => [],
        'isGroupable' => false
      )
    end
  end

  describe 'aggregationCapabilities' do
    it 'announces the time ranges the liana can label' do
      body = fetch_capabilities(['Tree'])

      expect(body['collections'].first['aggregationCapabilities']).to eq(
        'supportGroups' => true,
        'supportedDateOperations' => %w(Day Week Month Year)
      )
    end
  end

  # NOTICE: SQLite has no array column, and every collection of the dummy app has at least one
  #         groupable field, so both cases are announced off a stubbed apimap.
  describe 'a schema the dummy app cannot express' do
    def collection(name, fields)
      ForestLiana::Model::Collection.new(name: name, fields: fields)
    end

    before do
      allow(ForestLiana).to receive(:apimap).and_return([
        collection('WithAnArrayColumn', [
          { field: 'id', type: 'Number', is_primary_key: true },
          { field: 'tags', type: ['String'] }
        ]),
        collection('WithNothingGroupable', [
          { field: 'id', type: 'Number', is_primary_key: true },
          { field: 'computed', type: 'String', is_virtual: true }
        ])
      ])
    end

    # NOTICE: includes_all is the only operator the frontend offers on an array, and
    #         FiltersParser does not implement it.
    it 'announces no operator on an array column' do
      body = fetch_capabilities(['WithAnArrayColumn'])

      expect(field(body, 'WithAnArrayColumn', 'tags')).to eq(
        'name' => 'tags',
        'type' => ['String'],
        'operators' => [],
        'isGroupable' => true
      )
    end

    it 'announces no group support when nothing is groupable' do
      body = fetch_capabilities(['WithNothingGroupable'])

      expect(body['collections'].first['aggregationCapabilities']).to eq(
        'supportGroups' => false,
        'supportedDateOperations' => %w(Day Week Month Year)
      )
    end
  end
end
