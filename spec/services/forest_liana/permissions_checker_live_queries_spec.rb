module ForestLiana
  describe PermissionsChecker do
    before(:each) do
      described_class.empty_cache
    end

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
    let(:default_rendering_id) { 1 }
    let(:segments_permissions) { { default_rendering_id => { 'segments' => nil } } }
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
          'renderings' => segments_permissions
        },
        "meta" => {
          "rolesACLActivated" => true
        },
        "stats" => {
          "queries" => [
          'SELECT COUNT(*) AS value FROM products;',
          'SELECT COUNT(*) AS value FROM somethings;'
          ],
          "values" => [
            {
              "type" => "Value",
              "collection" => "Product",
              "aggregate" => "Count"
            }
          ],
        },
      }
    }

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

      context 'when permissions liveQueries' do
        let(:user) { { 'id' => '1', 'permission_level' => 'basic' } }
        context 'contains the query' do
          subject { described_class.new(fake_ressource, 'liveQueries', default_rendering_id, user: user, query_request_info: 'SELECT COUNT(*) AS value FROM somethings;') }

          it 'should be authorized' do
            expect(subject.is_authorized?).to be true
          end
        end

        context 'does not contains the query' do
          subject { described_class.new(fake_ressource, 'liveQueries', default_rendering_id, user: user, query_request_info: 'SELECT * FROM products WHERE category = Gifts OR 1=1-- AND released = 1') }
          it 'should NOT be authorized' do
            expect(subject.is_authorized?).to be false
          end
        end
      end

      context 'exectute liveQueries when user' do
        context 'has correct permission_level' do
          let(:user) { { 'id' => '1', 'permission_level' => 'admin' } }
          subject { described_class.new(fake_ressource, 'liveQueries', default_rendering_id, user: user, query_request_info: 'SELECT COUNT(*) AS value FROM somethings;') }

          it 'should be authorized' do
            expect(subject.is_authorized?).to be true
          end
        end

        context 'does not have the correct permission_level' do
          let(:user) { { 'id' => '1', 'permission_level' => 'basic' } }
          subject { described_class.new(fake_ressource, 'liveQueries', default_rendering_id, user: user, query_request_info: 'SELECT * FROM products WHERE category = Gifts OR 1=1-- AND released = 1') }
          it 'should NOT be authorized' do
            expect(subject.is_authorized?).to be false
          end
        end
      end

      context 'when permissions statWithParameters' do
        let(:user) { { 'id' => '1', 'permission_level' => 'basic' } }
        context 'contains the stat with the same parameters' do
          request_info = {
            "type" => "Value",
            "collection" => "Product",
            "aggregate" => "Count"
          };
          subject { described_class.new(fake_ressource, 'statWithParameters', default_rendering_id, user: user, query_request_info: request_info) }

          it 'should be authorized' do
            expect(subject.is_authorized?).to be true
          end
        end

        context 'does not contains the stat with the same parameters' do
          other_request_info = {
            "type" => "Leaderboard",
            "collection" => "Product",
            "aggregate" => "Sum"
          };
          subject { described_class.new(fake_ressource, 'statWithParameters', default_rendering_id, user: user, query_request_info: other_request_info) }
          it 'should NOT be authorized' do
            expect(subject.is_authorized?).to be false
          end
        end
      end

      context 'execute statWithParameters when user' do
        context 'has correct permission_level' do
          let(:user) { { 'id' => '1', 'permission_level' => 'admin' } }
          request_info = {
            "type" => "Value",
            "collection" => "Product",
            "aggregate" => "Count"
          };
          subject { described_class.new(fake_ressource, 'statWithParameters', default_rendering_id, user: user, query_request_info: request_info) }

          it 'should be authorized' do
            expect(subject.is_authorized?).to be true
          end
        end

        context 'does not contains the stat with the same parameters' do
          let(:user) { { 'id' => '1', 'permission_level' => 'basic' } }
          other_request_info = {
            "type" => "Leaderboard",
            "collection" => "Product",
            "aggregate" => "Sum"
          };
          subject { described_class.new(fake_ressource, 'statWithParameters', default_rendering_id, user: user, query_request_info: other_request_info) }
          it 'should NOT be authorized' do
            expect(subject.is_authorized?).to be false
          end
        end
      end
    end
  end
end
