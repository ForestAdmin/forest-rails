module ForestLiana
  module Ability
    # include ForestLiana::Ability::Permission
    describe Ability do
      let(:user) { { 'id' => 1, 'roleId' => 1, 'rendering_id' => 1 } }
      let(:action) {
        {
          'triggerEnabled' => [],
          'triggerConditions' => [],
          'approvalRequired' => [],
          'approvalRequiredConditions' => [],
          'userApprovalEnabled' => [],
          'userApprovalConditions' => [],
          'selfApprovalEnabled' => []
        }
      }

      let(:params) {
        {
          'data' => {
            'attributes' => {
              'values': {},
              'ids': [
                '1'
              ],
              'collection_name': 'Island',
              'parent_collection_name': nil,
              'parent_collection_id': nil,
              'parent_association_name': nil,
              'all_records': false,
              'all_records_subset_query': {
                'fields[Island]': 'is,name',
                'fields[file_attachment]': 'name',
                'fields[file_blob]': 'id',
                'page[number]': 1,
                'page[size]': 15,
                'sort': '-id',
                'timezone': 'Europe/Paris'
              },
              'all_records_ids_excluded': [],
              'smart_action_id': 'Island-my_action',
              'signed_approval_request': nil
            }
            }
          }
      }

      before do
        Island.create!(name: "foo")
      end

      describe 'can_execute with triggerEnabled' do
        it 'should return true if triggerConditions is empty and user can trigger' do
          parameters = ActionController::Parameters.new(params).permit!
          action['triggerEnabled'] = [1]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect(smart_action_checker.can_execute?).to equal true
        end

        it 'should return true if match triggerConditions and user can trigger' do
          parameters = ActionController::Parameters.new(params).permit!
          action['triggerEnabled'] = [1]
          action['triggerConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'foo',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect(smart_action_checker.can_execute?).to equal true
        end

        it 'should return true if match triggerConditions on allRecords and user can trigger' do
          params['data']['attributes']['all_records'] = true
          parameters = ActionController::Parameters.new(params).permit!
          action['triggerEnabled'] = [1]
          action['triggerConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'foo',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect(smart_action_checker.can_execute?).to equal true
        end

        it 'should raise error when user can not trigger' do
          parameters = ActionController::Parameters.new(params).permit!
          action['triggerEnabled'] = [2]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error(ForestLiana::Ability::Exceptions::TriggerForbidden)
        end

        it 'should raise error when triggerConditions not match' do
          parameters = ActionController::Parameters.new(params).permit!
          action['triggerEnabled'] = [1]
          action['triggerConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'fake island',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error ForestLiana::Ability::Exceptions::TriggerForbidden
        end

        it 'should raise error when conditions is on an unknown field' do
          parameters = ActionController::Parameters.new(params).permit!
          action['triggerEnabled'] = [1]
          action['triggerConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'unknown-field',
                        'value' => 'fake island',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error ForestLiana::Ability::Exceptions::ActionConditionError
        end
      end

      describe 'can_execute with approvalRequired' do
        it 'should raise RequireApproval error if approvalRequiredConditions is empty' do
          parameters = ActionController::Parameters.new(params).permit!
          action['approvalRequired'] = [1]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error ForestLiana::Ability::Exceptions::RequireApproval
        end

        it 'should expose the approver role ids and skip record ids on an explicit selection' do
          parameters = ActionController::Parameters.new(params).permit!
          action['approvalRequired'] = [1]
          action['userApprovalEnabled'] = [7]
          allow(ForestLiana::ResourcesGetter).to receive(:get_ids_from_request)
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error(ForestLiana::Ability::Exceptions::RequireApproval) do |error|
            expect(error.data[:roleIdsAllowedToApprove]).to eq([7])
            expect(error.data).not_to have_key(:recordIds)
          end
          expect(ForestLiana::ResourcesGetter).not_to have_received(:get_ids_from_request)
        end

        it 'should include the resolved record ids in the error on a "select all" trigger' do
          select_all_params = params.deep_dup
          select_all_params['data']['attributes'][:all_records] = true
          select_all_params['data']['attributes'][:ids] = []
          parameters = ActionController::Parameters.new(select_all_params).permit!
          action['approvalRequired'] = [1]
          action['userApprovalEnabled'] = [7]
          allow(ForestLiana::ResourcesGetter).to receive(:get_ids_from_request).and_return(%w[1 2 3])
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error(ForestLiana::Ability::Exceptions::RequireApproval) do |error|
            expect(error.data[:roleIdsAllowedToApprove]).to eq([7])
            expect(error.data[:recordIds]).to eq(%w[1 2 3])
          end
          # cap + excluded ids (none here) + 1: bounds the fetch instead of materializing the table
          expect(ForestLiana::ResourcesGetter).to have_received(:get_ids_from_request)
            .with(anything, anything, limit: 501)
        end

        it 'should not resolve record ids on a "select all" trigger of a global action' do
          select_all_params = params.deep_dup
          select_all_params['data']['attributes'][:all_records] = true
          select_all_params['data']['attributes'][:ids] = []
          parameters = ActionController::Parameters.new(select_all_params).permit!
          action['approvalRequired'] = [1]
          action['userApprovalEnabled'] = [7]
          allow(ForestLiana::ResourcesGetter).to receive(:get_ids_from_request)
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user, 'global')

          expect{smart_action_checker.can_execute?}.to raise_error(ForestLiana::Ability::Exceptions::RequireApproval) do |error|
            expect(error.data).not_to have_key(:recordIds)
          end
          expect(ForestLiana::ResourcesGetter).not_to have_received(:get_ids_from_request)
        end

        it 'should refuse a "select all" trigger resolving over 500 record ids' do
          select_all_params = params.deep_dup
          select_all_params['data']['attributes'][:all_records] = true
          select_all_params['data']['attributes'][:ids] = []
          parameters = ActionController::Parameters.new(select_all_params).permit!
          action['approvalRequired'] = [1]
          allow(ForestLiana::ResourcesGetter).to receive(:get_ids_from_request).and_return((1..501).map(&:to_s))
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error(
            ForestLiana::Ability::Exceptions::ApprovalSelectionTooLarge,
            /more than 500 records/
          )
        end

        it 'should raise RequireApproval error if match approvalRequiredConditions' do
          parameters = ActionController::Parameters.new(params).permit!
          action['approvalRequired'] = [1]
          action['approvalRequiredConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'foo',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error ForestLiana::Ability::Exceptions::RequireApproval
        end

        it 'should raise error when user can not trigger' do
          parameters = ActionController::Parameters.new(params).permit!
          action['approvalRequired'] = [2]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error(ForestLiana::Ability::Exceptions::TriggerForbidden)
        end

        it 'should trigger action when approvalRequiredCondition not match but with triggerConditions matched' do
          parameters = ActionController::Parameters.new(params).permit!
          action['approvalRequired'] = [1]
          action['triggerEnabled'] = [1]
          action['triggerConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'foo',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          action['approvalRequiredConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'fake island',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect(smart_action_checker.can_execute?).to equal true
        end

        it 'should raise error when approvalRequiredConditions and triggerConditions not match' do
          parameters = ActionController::Parameters.new(params).permit!
          action['approvalRequired'] = [1]
          action['triggerEnabled'] = [1]
          action['triggerConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'fake island',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          action['approvalRequiredConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'fake island',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error ForestLiana::Ability::Exceptions::TriggerForbidden
        end
      end

      describe 'can_execute with userApproval' do
        before do
          params['data']['attributes']['requester_id'] = 2
          request = params
          params['data']['attributes']['signed_approval_request'] = JWT::encode(request, ForestLiana.env_secret)
          action['userApprovalEnabled'] = [1]
        end

        it 'should return true if userApprovalConditions is empty and user has userApprovalEnabled permission' do
          parameters = ActionController::Parameters.new(params).permit!
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect(smart_action_checker.can_execute?).to equal true
        end

        it 'should return true when record match userApprovalConditions and requester_id different of current user id' do
          action['userApprovalConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'foo',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          parameters = ActionController::Parameters.new(params).permit!
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect(smart_action_checker.can_execute?).to equal true
        end

        it 'should return true when record match userApprovalConditions and user can self approve' do
          action['userApprovalConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'foo',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          action['selfApprovalEnabled'] = [1]
          params['data']['attributes']['requester_id'] = 2
          request = params
          params['data']['attributes']['signed_approval_request'] = JWT::encode(request, ForestLiana.env_secret)
          parameters = ActionController::Parameters.new(params).permit!
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect(smart_action_checker.can_execute?).to equal true
        end

        it 'should raise error when user has userApprovalEnabled permission' do
          parameters = ActionController::Parameters.new(params).permit!
          action['userApprovalEnabled'] = [2]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error(ForestLiana::Ability::Exceptions::TriggerForbidden)
        end

        it 'should raise error when triggerConditions not match' do
          parameters = ActionController::Parameters.new(params).permit!
          action['userApprovalConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'fake island',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error(ForestLiana::Ability::Exceptions::TriggerForbidden)
        end

        it 'should raise error when requester_id equal to current user id without selfApprove permission' do
          action['userApprovalConditions'] = [
            { 'filter' =>
                { 'aggregator' => 'and',
                  'conditions' =>
                    [
                      {
                        'field' => 'name',
                        'value' => 'foo',
                        'source' => 'data',
                        'operator' => 'equal'
                      }
                    ]
                },
              'roleId' => 1
            }
          ]
          params['data']['attributes']['requester_id'] = 1
          request = params
          params['data']['attributes']['signed_approval_request'] = JWT::encode(request, ForestLiana.env_secret)
          parameters = ActionController::Parameters.new(params).permit!
          smart_action_checker = ForestLiana::Ability::Permission::SmartActionChecker.new(parameters, Island, action, user)

          expect{smart_action_checker.can_execute?}.to raise_error(ForestLiana::Ability::Exceptions::TriggerForbidden)
        end
      end
    end
  end
end
