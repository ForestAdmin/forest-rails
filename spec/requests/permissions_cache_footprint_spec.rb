require 'rails_helper'

describe 'Permission and scope reads of a request', type: :request do
  token = JWT.encode({ id: 1, email: 'michael.kelso@that70.show', first_name: 'Michael', last_name: 'Kelso',
                       team: 'Operations', rendering_id: 16, exp: Time.now.to_i + 2.weeks.to_i,
                       permission_level: 'user' },
                     ForestLiana.auth_secret, 'HS256')
  headers = { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{token}" }

  let(:auth_headers) { headers }
  let(:readable) { %w[Tree Location User Island] }
  let(:refetched_readable) { readable }
  let(:scope) { { 'field' => 'name', 'operator' => 'present', 'value' => nil } }
  let!(:tree) do
    user = User.create!(name: 'Michel')
    tree = Tree.create!(name: 'Lemon Tree', owner: user, cutter: user)
    Location.create!(coordinates: '1,2', island: Island.create!(name: 'Lemon Island', trees: [tree]))
    tree
  end

  def environment(readable_collections)
    enabled = { 'roles' => [1] }
    collections = %w[Tree Location User Island].to_h do |name|
      read = readable_collections.include?(name) ? enabled : { 'roles' => [] }
      crud = %w[browseEnabled editEnabled addEnabled deleteEnabled exportEnabled].to_h { |key| [key, enabled] }
      [name, { 'collection' => crud.merge('readEnabled' => read), 'actions' => {} }]
    end

    { 'collections' => collections }
  end

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    @environment_fetches = 0
    allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions) do |_, path|
      case path
      when '/liana/v4/permissions/environment'
        @environment_fetches += 1
        environment(@environment_fetches == 1 ? readable : refetched_readable)
      when '/liana/v4/permissions/users'
        [{ 'id' => 1, 'roleId' => 1 }]
      end
    end
    rendering = Net::HTTPOK.new('1.1', 200, 'OK')
    allow(rendering).to receive(:body).and_return(JSON.generate(
      'collections' => { 'Tree' => { 'scope' => scope } }, 'team' => { 'id' => 1, 'name' => 'Operations' }
    ))
    allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(rendering)
    allow(ForestLiana::IpWhitelist).to receive(:retrieve) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_whitelist_retrieved) { true }
    allow(ForestLiana::IpWhitelist).to receive(:is_ip_valid) { true }
  end

  after do
    [Location, Tree, Island, User].each(&:destroy_all)
  end

  def cache_reads
    reads = Hash.new(0)
    subscriber = ActiveSupport::Notifications.subscribe('cache_read.active_support') do |*, payload|
      reads[payload[:key].to_s] += 1
    end
    yield
    reads
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  let(:fields) { { 'Tree' => 'id,name,owner', 'owner' => 'name' } }
  let(:filtered) do
    { fields: fields, filters: JSON.generate(field: 'owner:name', operator: 'present', value: nil),
      sort: 'owner.name', timezone: 'Europe/Paris' }
  end

  {
    'a list filtered and sorted on a relation' => ->(tree, params) { ['/forest/Tree', params.merge(page: { number: 1, size: 10 })] },
    'its count' => ->(tree, params) { ['/forest/Tree/count', params.except(:sort)] },
    'a get-one' => ->(tree, params) { ["/forest/Tree/#{tree.id}", { timezone: 'Europe/Paris' }] },
    'a related list' => ->(tree, _) { ["/forest/Island/#{tree.island_id}/relationships/trees", { fields: { 'Tree' => 'id,name,owner', 'owner' => 'name' }, timezone: 'Europe/Paris' }] },
  }.each do |name, request|
    it "reads each key at most once for #{name}" do
      path, params = request.call(tree, filtered)
      reads = cache_reads { get path, params: params, headers: auth_headers }

      expect(response).to have_http_status(200)
      expect(reads.keys).to include('forest.collections', 'forest.users')
      expect(reads.values).to all(eq(1))
    end
  end

  describe 'when a relation is denied by a stale cache' do
    let(:readable) { %w[Tree Location Island] }
    let(:refetched_readable) { %w[Tree Location User Island] }

    it 'refetches once and answers the rest of the request from the fresh permissions' do
      get '/forest/Tree', params: filtered.merge(page: { number: 1, size: 10 }), headers: auth_headers

      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body)['included'].map { |record| record['type'] }).to include('User')
      expect(@environment_fetches).to eq(2)
    end
  end
end
