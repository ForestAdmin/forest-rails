module ForestLiana
  describe PermissionsChecker do
    before(:each) do
      described_class.empty_cache
    end

    let(:schema) {
      [
        ForestLiana::Model::Collection.new({
          name: 'all_rights_collection',
          fields: [],
          actions: [
            ForestLiana::Model::Action.new({
              name: 'Test',
              endpoint: 'forest/actions/Test',
              http_method: 'POST'
            }), ForestLiana::Model::Action.new({
              name: 'TestRestricted',
              endpoint: 'forest/actions/Test-restricted',
              http_method: 'POST'
            })
          ]
        }), ForestLiana::Model::Collection.new({
          name: 'no_rights_collection',
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
    let(:default_api_permissions) {
      {
        "data" => {
          "all_rights_collection" => {
            "collection" => {
              "list" => true,
              "show" => true,
              "create" => true,
              "update" => true,
              "delete" => true,
              "export" => true,
              "searchToEdit" => true
            },
            "actions" => {
              "Test" => {
                "allowed" => true,
                "users" => nil
              },
              "TestRestricted" => {
                "allowed" => true,
                "users" => [1]
              }
            },
            "scope" => nil
          },
          "no_rights_collection" => {
            "collection" => {
              "list" => false,
              "show" => false,
              "create" => false,
              "update" => false,
              "delete" => false,
              "export" => false,
              "searchToEdit" => false
            },
            "actions" => {
              "Test" => {
                "allowed" => false,
                "users" => nil
              }
            },
            "scope" => nil
          },
        },
        "meta" => {
          "rolesACLActivated" => false
        }
      }
    }

    before do
      allow(ForestLiana).to receive(:apimap).and_return(schema)
    end

    describe 'handling cache' do
      let(:collection_name) { 'all_rights_collection' }
      let(:fake_ressource) { nil }
      let(:default_rendering_id) { 1 }

      before do
        allow(ForestLiana).to receive(:name_for).and_return(collection_name)
      end

      describe 'when calling twice the same permissions' do
        before do
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).and_return(default_api_permissions)
        end

        describe 'after expiration time' do
          before do
            allow(ENV).to receive(:[]).with('FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS').and_return('-1')
            # Needed to enforce ENV stub
            described_class.empty_cache
          end

          it 'should call the API twice' do
            described_class.new(fake_ressource, 'exportEnabled', default_rendering_id).is_authorized?
            described_class.new(fake_ressource, 'exportEnabled', default_rendering_id).is_authorized?

            expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).twice
          end
        end

        describe 'before expiration time' do
          it 'should call the API only once' do
            described_class.new(fake_ressource, 'exportEnabled', default_rendering_id).is_authorized?
            described_class.new(fake_ressource, 'exportEnabled', default_rendering_id).is_authorized?

            expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).once
          end
        end
      end

      describe 'with permissions coming from 2 different renderings' do
        before do
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering)
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(1).and_return(api_permissions_rendering_1)
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(2).and_return(api_permissions_rendering_2)
        end

        let(:collection_name) { 'custom' }
        let(:api_permissions_rendering_1) {
          {
            "data" => {
              "custom" => {
                "collection" => {
                  "list" => true,
                  "show" => true,
                  "create" => true,
                  "update" => true,
                  "delete" => true,
                  "export" => true,
                  "searchToEdit" => true
                },
                "actions" => { },
                "scope" => nil
              },
            },
            "meta" => {
              "rolesACLActivated" => false
            }
          }
        }
        let(:api_permissions_rendering_2) {
          api_permissions_rendering_2 = api_permissions_rendering_1.deep_dup
          api_permissions_rendering_2['data']['custom']['collection']['export'] = false
          api_permissions_rendering_2
        }
        let(:authorized_to_export_rendering_1) { described_class.new(fake_ressource, 'exportEnabled', 1).is_authorized? }
        let(:authorized_to_export_rendering_2) { described_class.new(fake_ressource, 'exportEnabled', 2).is_authorized? }

        it 'should return 2 different values' do
          expect(authorized_to_export_rendering_1).to eq true
          expect(authorized_to_export_rendering_2).to eq false
        end
      end
    end

    describe '#is_authorized?' do
      # Resource is only used to retrieve the collection name as it's stub it does not
      # need to be defined
      let(:fake_ressource) { nil }
      let(:default_rendering_id) { nil }
      let(:api_permissions) { default_api_permissions }
      let(:collection_name) { 'all_rights_collection' }

      before do
        allow(ForestLiana).to receive(:name_for).and_return(collection_name)
        allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).and_return(api_permissions)
      end

      describe 'when permissions does NOT have rolesACLActivated' do
        describe 'export permission' do
          let(:checker_instance) { described_class.new(fake_ressource, 'exportEnabled', default_rendering_id) }

          describe 'when user has the required permission' do
            it 'should be authorized' do
              expect(checker_instance.is_authorized?).to be true
            end
          end

          describe 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end
        end

        describe 'searchToEdit permission' do
          let(:checker_instance) { described_class.new(fake_ressource, 'searchToEdit', default_rendering_id) }

          describe 'when user has the required permission' do
            it 'should be authorized' do
              expect(checker_instance.is_authorized?).to be true
            end
          end

          describe 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end
        end

        describe 'list permission' do
          let(:collection_list_parameters) { { :user_id => "1", :filters => nil } }
          let(:checker_instance) {
            described_class.new(
              fake_ressource,
              'browseEnabled',
              default_rendering_id,
              nil,
              collection_list_parameters
            )
          }

          describe 'when user has the required permission' do
            it 'should be authorized' do
              expect(checker_instance.is_authorized?).to be true
            end
          end

          describe 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end
        end

        describe 'show permission' do
          let(:checker_instance) { described_class.new(fake_ressource, 'readEnabled', default_rendering_id) }

          describe 'when user has the required permission' do
            it 'should be authorized' do
              expect(checker_instance.is_authorized?).to be true
            end
          end

          describe 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end
        end

        describe 'create permission' do
          let(:checker_instance) { described_class.new(fake_ressource, 'addEnabled', default_rendering_id) }

          describe 'when user has the required permission' do
            it 'should be authorized' do
              expect(checker_instance.is_authorized?).to be true
            end
          end

          describe 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end
        end

        describe 'update permission' do
          let(:checker_instance) { described_class.new(fake_ressource, 'editEnabled', default_rendering_id) }

          describe 'when user has the required permission' do
            it 'should be authorized' do
              expect(checker_instance.is_authorized?).to be true
            end
          end

          describe 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end
        end

        describe 'delete permission' do
          let(:checker_instance) { described_class.new(fake_ressource, 'deleteEnabled', default_rendering_id) }

          describe 'when user has the required permission' do
            it 'should be authorized' do
              expect(checker_instance.is_authorized?).to be true
            end
          end

          describe 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end
        end

        describe 'actions permission' do
          let(:smart_action_request_info) { { endpoint: 'forest/actions/Test', http_method: 'POST' } }
          let(:checker_instance) {
            described_class.new(
              fake_ressource,
              'actions',
              default_rendering_id,
              smart_action_request_info
            )
          }

          describe 'when user has the required permission' do
            it 'should be authorized' do
              expect(checker_instance.is_authorized?).to be true
            end
          end

          describe 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end

          describe 'when endpoint is missing from smart action parameters' do
            let(:smart_action_request_info) { { http_method: 'POST' } }

            it 'user should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end

          describe 'when http_method is missing from smart action parameters' do
            let(:smart_action_request_info) { { endpoint: 'forest/actions/Test' } }

            it 'user should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end

          describe 'when the provided endpoint is not part of the schema' do
            let(:smart_action_request_info) { { endpoint: 'forest/actions/Test', http_method: 'DELETE' } }

            it 'user should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end

          describe 'when the action permissions contains a list of user ids' do
            describe 'when user id is NOT part of the authorized users' do
              # TODO ADAPT
              let(:smart_action_request_info) { { endpoint: 'forest/actions/Test', http_method: 'POST' } }

              it 'user should NOT be authorized' do
                expect(checker_instance.is_authorized?).to be false
              end
            end

            describe 'when user id is part of the authorized users' do
              # TODO ADAPT
              let(:smart_action_request_info) { { endpoint: 'forest/actions/Test', http_method: 'POST' } }

              it 'user should be authorized' do
                expect(checker_instance.is_authorized?).to be true
              end
            end
          end
        end
      end
    end
  end
end