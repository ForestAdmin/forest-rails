module ForestLiana
  describe PermissionsChecker do
    describe '#is_authorized?' do
      # Resource is only used to retrieve the collection name as it's stub it does not
      # need to be defined
      let(:fake_ressource) { nil }
      let(:default_rendering_id) { nil }
      let(:api_permissions) {
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
                "all_rights_collection-Test" => {
                  "allowed" => true,
                  "users" => nil
                },
                "all_rights_collection-TestRestricted" => {
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
                "no_rights_collection-Test" => {
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
        allow(ForestLiana).to receive(:name_for).and_return(collection_name)
        allow(ForestLiana::PermissionsGetter).to receive(:get_permissions_for_rendering).and_return(api_permissions)
      end

      describe 'when permissions does NOT have rolesACLActivated' do
        describe 'export permission' do
          let(:checker_instance) { described_class.new(fake_ressource, 'export', default_rendering_id) }

          describe 'when user has the required permission' do
            let(:collection_name) { 'all_rights_collection' }

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
            let(:collection_name) { 'all_rights_collection' }

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
              'list',
              default_rendering_id,
              nil,
              collection_list_parameters
            )
          }

          describe 'when user has the required permission' do
            let(:collection_name) { 'all_rights_collection' }

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
          let(:checker_instance) { described_class.new(fake_ressource, 'show', default_rendering_id) }

          describe 'when user has the required permission' do
            let(:collection_name) { 'all_rights_collection' }

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
          let(:checker_instance) { described_class.new(fake_ressource, 'create', default_rendering_id) }

          describe 'when user has the required permission' do
            let(:collection_name) { 'all_rights_collection' }

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
          let(:checker_instance) { described_class.new(fake_ressource, 'update', default_rendering_id) }

          describe 'when user has the required permission' do
            let(:collection_name) { 'all_rights_collection' }

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
          let(:checker_instance) { described_class.new(fake_ressource, 'delete', default_rendering_id) }

          describe 'when user has the required permission' do
            let(:collection_name) { 'all_rights_collection' }

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
          let(:smart_action_parameters) { { :user_id => "1", :action_id => "#{collection_name}-Test" } }
          let(:checker_instance) {
            described_class.new(
              fake_ressource,
              'actions',
              default_rendering_id,
              smart_action_parameters
            )
          }

          describe 'when user has the required permission' do
            let(:collection_name) { 'all_rights_collection' }

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

          describe 'when user_id is missing from smart action parameters' do
            let(:smart_action_parameters) { { :action_id => "#{collection_name}-Test" } }
            let(:collection_name) { 'all_rights_collection' }

            it 'user should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end

          describe 'when action_id is missing from smart action parameters' do
            let(:smart_action_parameters) { { :user_id => "1" } }
            let(:collection_name) { 'all_rights_collection' }

            it 'user should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end

          describe 'when the provided action is not part of the permissions' do
            let(:smart_action_parameters) { { :user_id => "1", :action_id => "#{collection_name}-Hide" } }
            let(:collection_name) { 'all_rights_collection' }

            it 'user should NOT be authorized' do
              expect(checker_instance.is_authorized?).to be false
            end
          end

          describe 'when the action permissions contains a list of user ids' do
            describe 'when user id is NOT part of the authorized users' do
              let(:smart_action_parameters) { { :user_id => "2", :action_id => "#{collection_name}-TestRestricted" } }

              let(:collection_name) { 'all_rights_collection' }

              it 'user should NOT be authorized' do
                expect(checker_instance.is_authorized?).to be false
              end
            end

            describe 'when user id is part of the authorized users' do
              let(:smart_action_parameters) { { :user_id => "1", :action_id => "#{collection_name}-TestRestricted" } }
              let(:collection_name) { 'all_rights_collection' }

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
