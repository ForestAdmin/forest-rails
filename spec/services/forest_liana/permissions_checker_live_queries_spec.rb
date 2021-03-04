module ForestLiana
  describe PermissionsChecker do
    before(:each) do
      described_class.empty_cache
    end

    let(:user_id) { 1 }
    let(:schema) {
      [
        ForestLiana::Model::Collection.new({
          name: 'all_rights_collection_boolean',
          fields: [],
          actions: [
            ForestLiana::Model::Action.new({
              name: 'Test',
              endpoint: 'forest/actions/Test',
              http_method: 'POST'
            })
          ]
        })
      ]
    }
    let(:scope_permissions) { nil }
    let(:default_api_permissions) {
      {
        "data" => {
          'collections' => {
            "all_rights_collection_boolean" => {
              "collection" => {
                "browseEnabled" => true,
                "readEnabled" => true,
                "editEnabled" => true,
                "addEnabled" => true,
                "deleteEnabled" => true,
                "exportEnabled" => true
              },
              "actions" => {
                "Test" => {
                  "triggerEnabled" => true
                },
              }
            },
          },
          'renderings' => scope_permissions
        },
        "meta" => {
          "rolesACLActivated" => true
        },
        "liveQueries" => [
          'SELECT COUNT(*) AS value FROM products;',
          'SELECT COUNT(*) AS value FROM sometings;'
        ]
      }
    }
    let(:default_rendering_id) { 1 }

    before do
      allow(ForestLiana).to receive(:apimap).and_return(schema)
    end

    describe '#is_authorized?' do
      # Resource is only used to retrieve the collection name as it's stub it does not
      # need to be defined
      let(:fake_ressource) { nil }
      let(:default_rendering_id) { nil }
      let(:api_permissions) { default_api_permissions }

      before do
        allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).and_return(api_permissions)
      end

      context 'when permissions liveQueries array' do
        context 'contains the query' do
          subject { described_class.new(fake_ressource, 'liveQueries', default_rendering_id, user_id: user_id, live_query_request_info: 'SELECT COUNT(*) AS value FROM sometings;') }

          it 'should be authorized' do
            expect(subject.is_authorized?).to be true
          end
        end

        context 'does not contains the query' do
          subject { described_class.new(fake_ressource, 'liveQueries', default_rendering_id, user_id: user_id, live_query_request_info: 'SELECT * FROM products WHERE category = Gifts OR 1=1-- AND released = 1') }
          it 'should NOT be authorized' do
            expect(subject.is_authorized?).to be false
          end
        end

      end
    end
  end
end
