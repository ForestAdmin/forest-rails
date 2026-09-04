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
    # NOTICE: Each flag flips in the ticket that implements it. canUseProjectionViaHeaderOnList
    #         stays false on purpose even though the list honours the header: the frontend also
    #         reads it as the floor for pruning projections by the role's read permission, which
    #         this liana does not implement yet.
    it 'announces the projection flags the routes honour' do
      body = fetch_capabilities(['Tree'])

      expect(body['agentCapabilities']).to eq(
        'canUseProjectionOnGetOne' => true,
        'canUseProjectionViaHeader' => true,
        'canUseProjectionViaHeaderOnList' => false,
        'canUseMultipleFieldsProjectionOnRelation' => true,
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
end
