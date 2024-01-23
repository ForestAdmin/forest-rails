module ForestLiana
  module Ability
    describe Ability do
      let(:dummy_class) { Class.new { extend ForestLiana::Ability } }
      let(:user) { { 'id' => 1, 'roleId' => 1, 'rendering_id' => '1' } }
      let(:permission) {
        {
          'Island' => {
            'browse' => [1],
            'read' => [1],
            'edit' => [1],
            'add' => [1],
            'delete' => [1],
            'export' => [1],
            :actions => {
                'my_action' => {
                    'triggerEnabled' => [1],
                    'triggerConditions' => [],
                    'approvalRequired' => [],
                    'approvalRequiredConditions' => [
                        { 'filter' =>
                            { 'aggregator' => 'and',
                              'conditions' =>
                                [
                                  { 'field' => 'price',
                                    'value' => '1',
                                    'source' => 'data',
                                    'operator' => 'greater_than' }
                                ]
                            },
                          'roleId' => 10
                        }
                    ],
                    'userApprovalEnabled' => [1],
                    'userApprovalConditions' =>
                      [
                        { 'filter' =>
                            { 'aggregator' => 'and',
                              'conditions' =>
                                [
                                  { 'field' => 'price',
                                    'value' => '1',
                                    'source' => 'data',
                                    'operator' => 'greater_than'
                                  }
                                ]
                            },
                          'roleId' => 11 }
                      ],
                    'selfApprovalEnabled' => [1]
                  }
            }
          }
        }
      }

      before do
        Rails.cache.clear
        Rails.cache.write('forest.users', {'1' => user})
        Rails.cache.write('forest.has_permission', true)
        Rails.cache.write('forest.collections',permission)
        Rails.cache.write('forest.stats', ['Leaderboard:b47e6fea7f7b9e2c7496d0c9399591f289552de6', 'Objective:fb40159a0cf0025de5fddf9a565e7ba2fef2c2b5', 'Value:b9a64a2ce88cb59ab5e2d5f5b25c6cfe35bf9350'])
        Island.create!(name: "L'île de la muerta")
      end

      describe 'is_crud_authorized' do
        it 'should return true when has_permission is false' do
          Rails.cache.clear
          allow_any_instance_of(ForestLiana::Ability::Fetch)
            .to receive(:get_permissions)
            .and_return(true)

          expect(dummy_class.is_crud_authorized?('browse', user, Island.first)).to equal true
        end

        it 'should return true when the action is in [browse read edit add delete export] list' do
          %w[browse read edit add delete export].each do |action|
            expect(dummy_class.is_crud_authorized?(action, user, Island)).to equal true
          end
        end

        it 'should throw an exception when the collection doesn\'t exist' do
            expect {dummy_class.is_crud_authorized?('browse', user, String)}.to raise_error(ForestLiana::Errors::ExpectedError, 'The collection String doesn\'t exist')
        end

        it 'should re-fetch the permission once when user permission is not allowed' do
          Rails.cache.write(
            'forest.collections',
            {
              'Island' => {
                'browse' => [2],
                'read' => [1],
                'edit' => [1],
                'add' => [1],
                'delete' => [1],
                'export' => [1],
                'actions' =>
                  {
                    'Mark as Live' => { 'triggerEnabled' => [10, 8, 9],
                                        'triggerConditions' => [],
                                        'approvalRequired' => [10, 8],
                                        'approvalRequiredConditions' =>
                                          [
                                            { 'filter' =>
                                                { 'aggregator' => 'and',
                                                  'conditions' =>
                                                    [
                                                      { 'field' => 'price',
                                                        'value' => 1,
                                                        'source' => 'data',
                                                        'operator' => 'greater_than'
                                                      }
                                                    ]
                                                },
                                              'roleId' => 10
                                            }
                                          ],
                                        'userApprovalEnabled' => [10, 8, 11],
                                        'userApprovalConditions' =>
                                          [
                                            { 'filter' =>
                                                { 'aggregator' => 'and',
                                                  'conditions' =>
                                                    [
                                                      { 'field' => 'price',
                                                        'value' => 1,
                                                        'source' => 'data',
                                                        'operator' => 'greater_than'
                                                      }
                                                    ]
                                                },
                                              'roleId' => 11 }
                                          ],
                                        'selfApprovalEnabled' => [8]
                    }
                  }
              }
            }
          )

          allow_any_instance_of(ForestLiana::Ability::Fetch)
            .to receive(:get_permissions)
            .and_return(
              {
                "collections" => {
                    "Island" => {
                        "collection" => {
                            "browseEnabled" => { "roles" => [1] },
                            "readEnabled" => { "roles" => [1] },
                            "editEnabled" => { "roles" => [1] },
                            "addEnabled" => { "roles" => [1] },
                            "deleteEnabled" => { "roles" => [1] },
                            "exportEnabled" => { "roles" => [1] }
                          },
                        "actions" => {

                        }
                      }
                  }
              }
            )

          expect(dummy_class.is_crud_authorized?('browse', user, Island)).to equal true
        end

        it 'should return false when user permission is not allowed' do
          Rails.cache.delete('forest.users')

          allow_any_instance_of(ForestLiana::Ability::Fetch)
            .to receive(:get_permissions)
            .with('/liana/v4/permissions/users')
            .and_return(
              [
                {"id"=>1, "firstName"=>"John", "lastName"=>"Doe", "email"=>"jd@forestadmin.com", "tags"=>{}, "roleId"=>'2', "permissionLevel"=>"admin"}
              ]
            )

          allow_any_instance_of(ForestLiana::Ability::Fetch)
            .to receive(:get_permissions)
            .with('/liana/v4/permissions/environment')
            .and_return(
              {
                "collections" => {
                  "Island" => {
                    "collection" => {
                      "browseEnabled" => { "roles" => [1] },
                      "readEnabled" => { "roles" => [1] },
                      "editEnabled" => { "roles" => [1] },
                      "addEnabled" => { "roles" => [1] },
                      "deleteEnabled" => { "roles" => [1] },
                      "exportEnabled" => { "roles" => [1] }
                    },
                    "actions"=>
                      {
                        "Mark as Live"=>
                          {
                            "triggerEnabled" => {"roles"=>[1]},
                            "triggerConditions" => [],
                            "approvalRequired" => {"roles" => [1]},
                            "approvalRequiredConditions" => [],
                            "userApprovalEnabled" => {"roles" => [1]},
                            "userApprovalConditions" => [],
                            "selfApprovalEnabled" => {"roles" => [1]}
                          }
                      }
                  }
                }
              }
            )

          expect(dummy_class.is_crud_authorized?('browse', user, Island)).to be false
        end
      end

      describe 'is_chart_authorized?' do
        it 'should return true when sha1 of parameters exist in the list of sha1 of forest.stats cache' do
          parameters = ActionController::Parameters.new(
            type: 'Objective',
            sourceCollectionName: 'Customer',
            aggregateFieldName: 'id',
            aggregator: 'Sum',
            objective: 20,
            filter: nil,
            contextVariables: ActionController::Parameters.new,
            timezone: 'Europe/Paris',
            controller: 'forest_liana/stats',
            action: 'get',
            collection: 'Customer'
          ).permit!

          expect(dummy_class.is_chart_authorized?(user, parameters)).to equal true
        end

        it 'should return false when sha1 of parameters doesn\'t exist in the list of sha1 of forest.stats cache' do
          parameters = ActionController::Parameters.new(
            type: 'Objective',
            sourceCollectionName: 'Product',
            aggregateFieldName: 'id',
            aggregator: 'Sum',
            objective: 20,
            filter: nil,
            contextVariables: ActionController::Parameters.new,
            timezone: 'Europe/Berlin',
            controller: 'forest_liana/stats',
            action: 'get',
            collection: 'Customer'
          ).permit!

          allow_any_instance_of(ForestLiana::Ability::Fetch)
            .to receive(:get_permissions)
            .and_return(
              {
                "stats" => [{
                  "type" => "Leaderboard",
                  "limit" => '1',
                  "aggregator" => "Count",
                  "labelFieldName" => "label",
                  "aggregateFieldName" => nil,
                  "relationshipFieldName" => "orders",
                  "sourceCollectionName" => "Product"
                }, {
                  "type" => "Objective",
                  "filter" => nil,
                  "objective" => '20',
                  "aggregator" => "Sum",
                  "aggregateFieldName" => "id",
                  "sourceCollectionName" => "Customer"
                }, {
                  "type" => "Value",
                  "filter" => {
                    "aggregator" => "and",
                    "conditions" => [{
                                       "field" => "price",
                                       "operator" => "greater_than",
                                       "value" => "{{dropdown1.selectedValue}}"
                                     }]
                  },
                  "aggregator" => "Count",
                  "aggregateFieldName" => nil,
                  "sourceCollectionName" => "Product"
                }],
              }
            )

          expect(dummy_class.is_chart_authorized?(user, parameters)).to equal false
        end
      end

      describe 'is_smart_action_authorized?' do
        let(:parameters)  {
            ActionController::Parameters.new(
              {
                "data": {
                  "attributes": {
                    "values": {},
                    "ids": [
                      "1"
                    ],
                    "collection_name": "Island",
                    "parent_collection_name": nil,
                    "parent_collection_id": nil,
                    "parent_association_name": nil,
                    "all_records": false,
                    "all_records_subset_query": {
                      "fields[Island]": "id,name",
                      "fields[file_attachment]": "name",
                      "fields[file_blob]": "id",
                      "page[number]": 1,
                      "page[size]": 15,
                      "sort": "-id",
                      "timezone": "Europe/Paris"
                    },
                    "all_records_ids_excluded": ["3", "2"],
                    "smart_action_id": "my_action",
                    "signed_approval_request": nil
                  }
                }
              }
          ).permit!
        }

        it 'should return true' do
          expect(dummy_class.is_smart_action_authorized?(user, Island,  parameters, '/forest/actions/my_action', 'POST')).to equal true
        end

        it 'should throw an exception when the collection doesn\'t exist' do
          expect {dummy_class.is_smart_action_authorized?(user, String, parameters, '/forest/actions/my_action', 'POST')}.to raise_error(ForestLiana::Errors::ExpectedError, 'The collection String doesn\'t exist')
        end
      end

      describe 'when the server doesn\'t return an success response' do
        before do
          Rails.cache.clear
        end

        it 'should return an exception' do
          allow(ForestLiana::ForestApiRequester).to receive(:get).and_return(instance_double(HTTParty::Response, code: 500, body: nil))
          expect { dummy_class.is_crud_authorized?('browse', user, Island.first) }.to raise_error(ForestLiana::Errors::HTTP403Error, 'Permission could not be retrieved')
        end
      end
    end
  end
end
