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
