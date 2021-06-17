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
        }), ForestLiana::Model::Collection.new({
          name: 'no_rights_collection_boolean',
          fields: [],
          actions: [
            ForestLiana::Model::Action.new({
              name: 'Test',
              endpoint: 'forest/actions/Test',
              http_method: 'POST'
            })
          ]
        }), ForestLiana::Model::Collection.new({
          name: 'all_rights_collection_user_list',
          fields: [],
          actions: [
            ForestLiana::Model::Action.new({
              name: 'Test',
              endpoint: 'forest/actions/Test',
              http_method: 'POST'
            })
          ]
        }), ForestLiana::Model::Collection.new({
          name: 'no_rights_collection_user_list',
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
    let(:scope_permissions) { { default_rendering_id => { 'scopes' => nil } } }
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
            "all_rights_collection_user_list" => {
              "collection" => {
                "browseEnabled" => [1],
                "readEnabled" => [1],
                "editEnabled" => [1],
                "addEnabled" => [1],
                "deleteEnabled" => [1],
                "exportEnabled" => [1]
              },
              "actions" => {
                "Test" => {
                  "triggerEnabled" => [1]
                },
              }
            },
            "no_rights_collection_boolean" => {
              "collection" => {
                "browseEnabled" => false,
                "readEnabled" => false,
                "editEnabled" => false,
                "addEnabled" => false,
                "deleteEnabled" => false,
                "exportEnabled" => false
              },
              "actions" => {
                "Test" => {
                  "triggerEnabled" => false
                },
              }
            },
            "no_rights_collection_user_list" => {
              "collection" => {
                "browseEnabled" => [],
                "readEnabled" => [],
                "editEnabled" => [],
                "addEnabled" => [],
                "deleteEnabled" => [],
                "exportEnabled" => []
              },
              "actions" => {
                "Test" => {
                  "triggerEnabled" => []
                },
              }
            },
          },
          'renderings' => scope_permissions
        },
        "stats" => {
          "queries"=>[],
        },
        "meta" => {
          "rolesACLActivated" => true
        }
      }
    }

    before do
      allow(ForestLiana).to receive(:apimap).and_return(schema)
      allow(ForestLiana).to receive(:name_for).and_return(collection_name)
    end

    describe 'handling cache' do
      let(:collection_name) { 'all_rights_collection_boolean' }
      let(:fake_ressource) { collection_name }
      let(:default_rendering_id) { 1 }

      context 'collections cache' do
        context 'when calling twice the same permissions' do
          before do
            allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).and_return(default_api_permissions)
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
          before do
            allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering)
            allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(1).and_return(api_permissions_rendering_1)
            allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(2).and_return(api_permissions_rendering_2)
          end

          let(:collection_name) { 'custom' }
          let(:scope_permissions) { { default_rendering_id => { 'custom' => nil }, 2 => { 'custom' => nil } } }
          let(:api_permissions_rendering_1) {
            {
              "data" => {
                'collections' => {
                  "custom" => {
                    "collection" => {
                      "browseEnabled" => false,
                      "readEnabled" => true,
                      "editEnabled" => true,
                      "addEnabled" => true,
                      "deleteEnabled" => true,
                      "exportEnabled" => true
                    },
                    "actions" => { }
                  },
                },
                'renderings' => scope_permissions
              },
              "meta" => {
                "rolesACLActivated" => true
              }
            }
          }
          let(:api_permissions_rendering_2) {
            api_permissions_rendering_2 = api_permissions_rendering_1.deep_dup
            api_permissions_rendering_2['data']['collections']['custom']['collection']['exportEnabled'] = false
            api_permissions_rendering_2['data']['collections']['custom']['collection']['browseEnabled'] = true
            api_permissions_rendering_2
          }

          context 'when the first call is authorized' do
            let(:authorized_to_export_rendering_1) { described_class.new(fake_ressource, 'exportEnabled', 1, user_id: user_id).is_authorized? }
            let(:authorized_to_export_rendering_2) { described_class.new(fake_ressource, 'exportEnabled', 2, user_id: user_id).is_authorized? }

            # Even if the value are different, the permissions are cross rendering thus another call
            # to the api wont be made until the permission expires
            it 'should return the same value' do
              expect(authorized_to_export_rendering_1).to eq true
              expect(authorized_to_export_rendering_2).to eq true
            end

            it 'should call the API only once' do
              authorized_to_export_rendering_1
              authorized_to_export_rendering_2
              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).once
            end
          end

          # If not authorized the cached version is not used
          context 'when the first call is not authorized' do
            let(:authorized_to_export_rendering_1) { described_class.new(fake_ressource, 'browseEnabled', 1, user_id: user_id).is_authorized? }
            let(:authorized_to_export_rendering_2) { described_class.new(fake_ressource, 'browseEnabled', 2, user_id: user_id).is_authorized? }

            it 'should return different value' do
              expect(authorized_to_export_rendering_1).to eq false
              expect(authorized_to_export_rendering_2).to eq true
            end

            it 'should call the API twice' do
              authorized_to_export_rendering_1
              authorized_to_export_rendering_2
              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).twice
            end
          end
        end
      end

      context 'scopes cache' do
        let(:rendering_id) { 1 }
        let(:collection_name) { 'custom' }
        let(:scope_permissions) { { rendering_id => { 'custom' => nil } } }
        let(:api_permissions) {
          {
            "data" => {
              'collections' => {
                "custom" => {
                  "collection" => {
                    "browseEnabled" => true,
                    "readEnabled" => true,
                    "editEnabled" => true,
                    "addEnabled" => true,
                    "deleteEnabled" => true,
                    "exportEnabled" => true
                  },
                  "actions" => { }
                },
              },
              'renderings' => scope_permissions
            },
            "meta" => {
              "rolesACLActivated" => true
            }
          }
        }
        let(:api_permissions_scope_only) {
          {
            "data" => {
              'collections' => { },
              'renderings' => scope_permissions
            },
            "meta" => {
              "rolesACLActivated" => true
            }
          }
        }

        before do
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(rendering_id).and_return(api_permissions)
          allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true).and_return(api_permissions_scope_only)
        end

        context 'when checking once for authorization' do
          context 'when checking browseEnabled' do
            context 'when expiration value is set to its default' do
              it 'should not call the API to refresh the scopes cache' do
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

              it 'should call the API to refresh the scopes cache' do
                described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?

                expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
                expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true).once
              end
            end
          end

          # Only browse permission requires scopes
          context 'when checking exportEnabled' do
            context 'when expiration value is set in the past' do
              before do
                allow(ENV).to receive(:[]).with('FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS').and_return('-1')
                # Needed to enforce ENV stub
                described_class.empty_cache
              end
            end

            it 'should NOT call the API to refresh the scopes cache' do
              described_class.new(fake_ressource, 'exportEnabled', rendering_id, user_id: user_id).is_authorized?

              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
              expect(ForestLiana::PermissionsGetter).not_to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true)
            end
          end
        end

        context 'when checking twice for authorization' do
          context 'on the same rendering' do
            context 'when scopes permission has NOT expired' do
              it 'should NOT call the API to refresh the scopes permissions' do
                described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?
                described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?

                expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
                expect(ForestLiana::PermissionsGetter).not_to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true)
              end
            end

            context 'when scopes permission has expired' do
              before do
                allow(ENV).to receive(:[]).with('FOREST_PERMISSIONS_EXPIRATION_IN_SECONDS').and_return('-1')
                # Needed to enforce ENV stub
                described_class.empty_cache
              end

              it 'should call the API to refresh the scopes permissions' do
                described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?
                described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?

                expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).twice
                expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id, rendering_specific_only: true).twice
              end
            end
          end

          context 'on two different renderings' do
            let(:other_rendering_id) { 2 }
            let(:api_permissions_scope_only) {
              {
                "data" => {
                  'collections' => { },
                  'renderings' => {
                    other_rendering_id => { 'custom' => nil }
                  }
                },
                "stats" => {
                  "somestats" => [],
                },
                "meta" => {
                  "rolesACLActivated" => true
                }
              }
            }

            before do
              allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).with(other_rendering_id, rendering_specific_only: true).and_return(api_permissions_scope_only)
            end

            it 'should call the API to refresh the scopes permissions' do
              described_class.new(fake_ressource, 'browseEnabled', rendering_id, user_id: user_id).is_authorized?
              described_class.new(fake_ressource, 'browseEnabled', other_rendering_id, user_id: user_id).is_authorized?

              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(rendering_id).once
              expect(ForestLiana::PermissionsGetter).to have_received(:get_permissions_for_rendering).with(other_rendering_id, rendering_specific_only: true).once
            end
          end
        end
      end
    end

    describe '#is_authorized?' do
      # Resource is only used to retrieve the collection name as it's stub it does not
      # need to be defined
      let(:fake_ressource) { collection_name }
      let(:default_rendering_id) { nil }
      let(:api_permissions) { default_api_permissions }

      before do
        allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).and_return(api_permissions)
      end

      context 'when permissions have rolesACLActivated' do
        context 'with true/false permission values' do
          let(:collection_name) { 'all_rights_collection_boolean' }

          describe 'exportEnabled permission' do
            subject { described_class.new(fake_ressource, 'exportEnabled', default_rendering_id, user_id: user_id) }

            context 'when user has the required permission' do
              it 'should be authorized' do
                expect(subject.is_authorized?).to be true
              end
            end

            context 'when user has not the required permission' do
              let(:collection_name) { 'no_rights_collection_boolean' }

              it 'should NOT be authorized' do
                expect(subject.is_authorized?).to be false
              end
            end
          end

          describe 'browseEnbled permission' do
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

            context 'when user has not the required permission' do
              let(:collection_name) { 'no_rights_collection_boolean' }

              it 'should NOT be authorized' do
                expect(subject.is_authorized?).to be false
              end
            end

            context 'when scopes are defined' do
              let(:default_rendering_id) { 1 }
              let(:scope_permissions) {
                {
                  default_rendering_id => {
                    collection_name => {
                      'scope' => {
                        'dynamicScopesValues' => {},
                        'filter' => { 'aggregator' => 'and', 'conditions' => [condition] }
                      }
                    }
                  }
                }
              }
              let(:collection_list_parameters) { { :user_id => "1", :filters => JSON.generate(condition) } }

              context 'when scopes are passing validation' do
                context 'when scope value is a string' do
                  let(:condition) { { 'field' => 'field_1', 'operator' => 'equal', 'value' => true } }

                  it 'should return true' do
                    expect(subject.is_authorized?).to be true
                  end
                end

                context 'when scope value is a boolean' do
                  let(:condition) { { 'field' => 'field_1', 'operator' => 'equal', 'value' => 'true' } }

                  it 'should return true' do
                    expect(subject.is_authorized?).to be true
                  end
                end
              end

              context 'when scopes are NOT passing validation' do
                let(:condition) { { 'field' => 'field_1', 'operator' => 'equal', 'value' => true } }
                let(:other_condition) {
                  {
                    aggregator: 'and',
                    conditions: [
                      { field: 'name', value: 'john', operator: 'equal' },
                      { field: 'price', value: '2500', operator: 'equal' }
                    ]
                  }
                }
                let(:collection_list_parameters) {
                  {
                    :user_id => "1",
                    :filters => JSON.generate(other_condition)
                  }
                }

                it 'should return false' do
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
              let(:collection_name) { 'no_rights_collection_boolean' }

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
              let(:collection_name) { 'no_rights_collection_boolean' }

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
              let(:collection_name) { 'no_rights_collection_boolean' }

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
              let(:collection_name) { 'no_rights_collection_boolean' }

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
              let(:collection_name) { 'no_rights_collection_boolean' }

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
          end
        end

        context 'with userId list permission values' do
          let(:collection_name) { 'all_rights_collection_user_list' }

          describe 'exportEnabled permission' do
            subject { described_class.new(fake_ressource, 'exportEnabled', default_rendering_id, user_id: user_id) }

            context 'when user has the required permission' do
              it 'should be authorized' do
                expect(subject.is_authorized?).to be true
              end
            end

            context 'when user has not the required permission' do
              let(:collection_name) { 'no_rights_collection_user_list' }

              it 'should NOT be authorized' do
                expect(subject.is_authorized?).to be false
              end
            end
          end

          describe 'browseEnabled permission' do
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

            context 'when user has not the required permission' do
              let(:collection_name) { 'no_rights_collection_user_list' }

              it 'should NOT be authorized' do
                expect(subject.is_authorized?).to be false
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
              let(:collection_name) { 'no_rights_collection_user_list' }

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
              let(:collection_name) { 'no_rights_collection_user_list' }

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
              let(:collection_name) { 'no_rights_collection_user_list' }

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
              let(:collection_name) { 'no_rights_collection_user_list' }

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
              let(:collection_name) { 'no_rights_collection_user_list' }

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
          end

          # searchToEdit permission checker should not be called anymore once rolesAcl activated
          describe 'searchToEdit permission' do
            subject { described_class.new(fake_ressource, 'searchToEdit', default_rendering_id, user_id: user_id) }

            context 'when user has all permissions' do
              it 'should NOT be authorized' do
                expect(subject.is_authorized?).to be false
              end
            end

            context 'when user has no permissions' do
              let(:collection_name) { 'no_rights_collection_user_list' }

              it 'should NOT be authorized' do
                expect(subject.is_authorized?).to be false
              end
            end
          end
        end
      end
    end
  end
end
