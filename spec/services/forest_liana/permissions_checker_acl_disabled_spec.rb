module ForestLiana
  describe PermissionsChecker do
    before(:each) do
      described_class.empty_cache
    end

    let(:user_id) { 1 }
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
              name: 'TestPut',
              endpoint: 'forest/actions/Test',
              http_method: 'PUT'
            }), ForestLiana::Model::Action.new({
              name: 'TestRestricted',
              endpoint: 'forest/actions/TestRestricted',
              http_method: 'POST'
            }), ForestLiana::Model::Action.new({
              name: 'Test Default Values',
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
        }), ForestLiana::Model::Collection.new({
          name: 'custom',
          fields: [],
          actions: []
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
              "TestPut" => {
                "allowed" => false,
                "users" => nil
              },
              "TestRestricted" => {
                "allowed" => true,
                "users" => [1]
              },
              "Test Default Values" => {
                "allowed" => true,
                "users" => nil
              },
            },
            "segments" => nil
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
            "segments" => nil
          },
        },
        "meta" => {
          "rolesACLActivated" => false
        }
      }
    }

    before do
      allow(ForestLiana).to receive(:name_for).and_return(collection_name)
      allow(ForestLiana).to receive(:apimap).and_return(schema)
    end

    describe 'handling cache' do
      let(:collection_name) { 'all_rights_collection' }
      let(:fake_ressource) { collection_name }
      let(:default_rendering_id) { 1 }

      context 'when calling twice the same permissions' do
        before do
          # clones is called to duplicate the returned value and not use to same (which results in an error
          # as the permissions is edited through the formatter)
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering) { default_api_permissions.clone }
        end

        context 'after expiration time' do
          before do
            allow(ENV).to receive(:[]).with('FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS').and_return('-1')
            # Needed to enforce ENV stub
            described_class.empty_cache
          end

          it 'should call the API twice' do
            described_class.new(fake_ressource, 'exportEnabled', default_rendering_id, user_id: user_id).is_authorized?
            described_class.new(fake_ressource, 'exportEnabled', default_rendering_id, user_id: user_id).is_authorized?

            expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).twice
          end
        end

        context 'before expiration time' do
          it 'should call the API only once' do
            described_class.new(fake_ressource, 'exportEnabled', default_rendering_id, user_id: user_id).is_authorized?
            described_class.new(fake_ressource, 'exportEnabled', default_rendering_id, user_id: user_id).is_authorized?

            expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).once
          end
        end
      end

      context 'with permissions coming from 2 different renderings' do
        let(:collection_name) { 'custom' }

        let(:segments_permissions) { nil }
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
                "segments" => segments_permissions
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
        let(:authorized_to_export_rendering_1) { described_class.new(fake_ressource, 'exportEnabled', 1, user_id: user_id).is_authorized? }
        let(:authorized_to_export_rendering_2) { described_class.new(fake_ressource, 'exportEnabled', 2, user_id: user_id).is_authorized? }

        before do
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering)
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(1).and_return(api_permissions_rendering_1)
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(2).and_return(api_permissions_rendering_2)
        end

        it 'should return 2 different values' do
          expect(authorized_to_export_rendering_1).to eq true
          expect(authorized_to_export_rendering_2).to eq false
        end
      end
    end


    context 'renderings cache' do
      let(:fake_ressource) { collection_name }
      let(:rendering_id) { 1 }
      let(:collection_name) { 'custom' }
      let(:segments_permissions) { { rendering_id => { 'custom' => nil } } }
      let(:api_permissions) {
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
              "segments" => nil
            },
          },
          "meta" => {
            "rolesACLActivated" => false
          }
        }
      }
      let(:api_permissions_rendering_only) {
        {
          "data" => {
            'collections' => { },
            'renderings' => segments_permissions
          },
          "meta" => {
            "rolesACLActivated" => false
          }
        }
      }

      before do
        # clones is called to duplicate the returned value and not use to same (which results in an error
        # as the permissions is edited through the formatter)
        allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(rendering_id) { api_permissions.clone }
        allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true).and_return(api_permissions_rendering_only)
      end

      context 'when checking once for authorization' do
        context 'when checking browseEnabled' do
          context 'when expiration value is set to its default' do
            it 'should not call the API to refresh the renderings cache' do
              described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?

              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
              expect(ForestLiana::PermissionsGetter).not_to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true)
            end
          end

          context 'when expiration value is set in the past' do
            before do
              allow(ENV).to receive(:[]).with('FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS').and_return('-1')
              # Needed to enforce ENV stub
              described_class.empty_cache
            end

            it 'should call the API to refresh the renderings cache' do
              described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?

              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true).once
            end
          end
        end

        # Only browse permission requires segments
        context 'when checking exportEnabled' do
          context 'when expiration value is set in the past' do
            before do
              allow(ENV).to receive(:[]).with('FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS').and_return('-1')
              # Needed to enforce ENV stub
              described_class.empty_cache
            end
          end

          it 'should NOT call the API to refresh the renderings cache' do
            described_class.new(fake_ressource, 'exportEnabled', rendering_id, user_id: user_id).is_authorized?

            expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
            expect(ForestLiana::PermissionsGetter).not_to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true)
          end
        end
      end

      context 'when checking twice for authorization' do
        context 'on the same rendering' do
          context 'when renderings permission has NOT expired' do
            it 'should NOT call the API to refresh the renderings permissions' do
              described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?
              described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?

              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
              expect(ForestLiana::PermissionsGetter).not_to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true)
            end
          end

          context 'when renderings permission has expired' do
            before do
              allow(ENV).to receive(:[]).with('FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS').and_return('-1')
              # Needed to enforce ENV stub
              described_class.empty_cache
            end

            it 'should call the API to refresh the renderings permissions' do
              described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?
              described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?

              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).twice
              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true).twice
            end
          end
        end

        context 'on two different renderings' do
          let(:other_rendering_id) { 2 }
          let(:api_permissions_rendering_only) {
            {
              "data" => {
                'collections' => { },
                'renderings' => {
                  '2' => { 'custom' => nil }
                }
              },
              "meta" => {
                "rolesACLActivated" => false
              }
            }
          }
          let(:api_permissions_copy) { api_permissions.clone }

          before do
            allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(other_rendering_id).and_return(api_permissions_copy)
            allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(other_rendering_id, rendering_specific_only: true).and_return(api_permissions_rendering_only)
          end

          it 'should not call the API to refresh the rederings permissions' do
            described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?
            described_class.new(fake_ressource, 'browseEnabled', other_rendering_id, user_id: user_id).is_authorized?

            expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
            expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(other_rendering_id).once
            expect(ForestLiana::PermissionsGetter).not_to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true)
            expect(ForestLiana::PermissionsGetter).not_to have_received(:get_permissions_for_rendering).with(other_rendering_id, rendering_specific_only: true)
          end
        end
      end
    end

    describe '#is_authorized?' do
      # Resource is only used to retrieve the collection name as it's stubbed it does not
      # need to be defined
      let(:fake_ressource) { collection_name }
      let(:default_rendering_id) { 1 }
      let(:api_permissions) { default_api_permissions }
      let(:collection_name) { 'all_rights_collection' }

      before do
        allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).and_return(api_permissions)
      end

      context 'when permissions does NOT have rolesACLActivated' do
        describe 'exportEnabled permission' do
          subject { described_class.new(fake_ressource, 'exportEnabled', default_rendering_id, user_id: user_id) }

          context 'when user has the required permission' do
            it 'should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end
        end

        describe 'browseEnabled permission' do
          let(:collection_name) { 'custom' }
          subject { described_class.new(fake_ressource, 'browseEnabled', default_rendering_id, user_id: user_id) }
          let(:segments_permissions) { nil }
          let(:default_api_permissions) {
            {
              "data" => {
                "custom" => {
                  "collection" => collection_permissions,
                  "actions" => { },
                  "segments" => segments_permissions
                },
              },
              "meta" => {
                "rolesACLActivated" => false
              }
            }
          }

          context 'when user has list permission' do
            let(:collection_permissions) {
              {
                "list" => true,
                "show" => false,
                "create" => false,
                "update" => false,
                "delete" => false,
                "export" => false,
                "searchToEdit" => false
              }
            }

            it 'should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when user has searchToEdit permission' do
            let(:collection_permissions) {
              {
                "list" => false,
                "show" => false,
                "create" => false,
                "update" => false,
                "delete" => false,
                "export" => false,
                "searchToEdit" => true
              }
            }

            it 'should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when user has not the list nor the searchToEdit permission' do
            let(:collection_permissions) {
              {
                "list" => false,
                "show" => false,
                "create" => false,
                "update" => false,
                "delete" => false,
                "export" => false,
                "searchToEdit" => false
              }
            }

            it 'should be NOT authorized' do
              expect(subject.is_authorized?).to be false
            end
          end

          context 'when providing collection_list_parameters' do
            let(:collection_permissions) {
              {
                "list" => true,
                "show" => false,
                "create" => false,
                "update" => false,
                "delete" => false,
                "export" => false,
                "searchToEdit" => false
              }
            }
            let(:collection_list_parameters) { { :user_id => "1", :filters => nil } }

            subject {
              described_class.new(
                fake_ressource,
                'browseEnabled',
                default_rendering_id,
                user_id: user_id,
                collection_list_parameters: collection_list_parameters
              )
            }

            context 'when user has the required permission' do
              it 'should be authorized' do
                expect(subject.is_authorized?).to be true
              end
            end

            context 'when segments are defined' do
              let(:segments_permissions) { ['SELECT * FROM products;', 'SELECT * FROM sellers;'] }
              let(:collection_list_parameters) { { :user_id => "1", :segmentQuery => segmentQuery } }

              context 'when segments are passing validation' do
                  let(:segmentQuery) { 'SELECT * FROM products;' }
                  it 'should return true' do
                    expect(subject.is_authorized?).to be true
                  end
              end

              context 'when segments are NOT passing validation' do
                let(:segmentQuery) { 'SELECT * FROM rockets WHERE name = "Starship";' }
                it 'should return false' do
                  expect(subject.is_authorized?).to be false
                end
              end
            
            end

            context 'when user has not the required permission' do
              let(:collection_permissions) {
                {
                  "list" => false,
                  "show" => false,
                  "create" => false,
                  "update" => false,
                  "delete" => false,
                  "export" => false,
                  "searchToEdit" => false
                }
              }

              it 'should NOT be authorized' do
                expect(subject.is_authorized?).to be false
              end
            end

          end
        end

        describe 'readEnabled permission' do
          subject { described_class.new(fake_ressource, 'readEnabled', default_rendering_id, user_id: user_id) }

          context 'when user has the required permission' do
            it 'should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end
        end

        describe 'addEnabled permission' do
          subject { described_class.new(fake_ressource, 'addEnabled', default_rendering_id, user_id: user_id) }

          context 'when user has the required permission' do
            it 'should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end
        end

        describe 'editEnabled permission' do
          subject { described_class.new(fake_ressource, 'editEnabled', default_rendering_id, user_id: user_id) }

          context 'when user has the required permission' do
            it 'should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end
        end

        describe 'deleteEnabled permission' do
          subject { described_class.new(fake_ressource, 'deleteEnabled', default_rendering_id, user_id: user_id) }

          context 'when user has the required permission' do
            it 'should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end
        end

        describe 'actions permission' do
          let(:smart_action_request_info) { { endpoint: 'forest/actions/Test', http_method: 'POST' } }
          subject {
            described_class.new(
              fake_ressource,
              'actions',
              default_rendering_id,
              user_id: user_id,
              smart_action_request_info: smart_action_request_info
            )
          }

          context 'when user has the required permission' do

            it 'should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when user has not the required permission' do
            let(:collection_name) { 'no_rights_collection' }

            it 'should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end

          context 'when endpoint is missing from smart action parameters' do
            let(:smart_action_request_info) { { http_method: 'POST' } }

            it 'user should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end

          context 'when http_method is missing from smart action parameters' do
            let(:smart_action_request_info) { { endpoint: 'forest/actions/Test' } }

            it 'user should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end

          context 'when the provided endpoint is not part of the schema' do
            let(:smart_action_request_info) { { endpoint: 'forest/actions/Test', http_method: 'DELETE' } }

            it 'user should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end

          context 'when the action permissions contains a list of user ids' do
            context 'when user id is NOT part of the authorized users' do
              let(:user_id) { 2 }
              let(:smart_action_request_info) { { endpoint: 'forest/actions/TestRestricted', http_method: 'POST' } }

              it 'user should NOT be authorized' do
                expect(subject.is_authorized?).to be false
              end
            end

            context 'when user id is part of the authorized users' do
              let(:smart_action_request_info) { { endpoint: 'forest/actions/TestRestricted', http_method: 'POST' } }

              it 'user should be authorized' do
                expect(subject.is_authorized?).to be true
              end
            end
          end

          context 'when the action has been created with default http endpoint and method in the schema' do
            let(:smart_action_request_info) { { endpoint: 'forest/actions/test-default-values', http_method: 'POST' } }

            it 'user should be authorized' do
              expect(subject.is_authorized?).to be true
            end
          end

          context 'when the action has the same enpoint as an other' do
            let(:smart_action_request_info) { { endpoint: 'forest/actions/Test', http_method: 'PUT' } }

            it 'user should NOT be authorized' do
              expect(subject.is_authorized?).to be false
            end
          end
        end
      end
    end
  end
end
