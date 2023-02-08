module ForestLiana
  module Ability
    describe Ability do
      let(:dummy_class) { Class.new { extend ForestLiana::Ability } }
      let(:user) { { 'id' => 1, 'roleId' => 1 } }
      let(:cache) { Rails.cache }
      let(:permission) {
        {
          'Island' => {
            'browse' => [1],
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
                                                    'operator' => 'greater_than' }
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
      }

      before do
        Rails.cache.clear
        Rails.cache.write('forest.users', {'1' => user})
        Rails.cache.write('forest.has_permission', true)
        Rails.cache.write(
          'forest.collections',
          permission
        )
        Island.create!(name: "L'île de la muerta")
      end

      describe 'is_crud_authorized' do
        it 'should return true when has_permission is false' do
          Rails.cache.clear
          allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions).and_return(true)

          expect(dummy_class.is_crud_authorized?('browse', user, Island.first)).to equal true
        end

        it 'should return true when the action is in [browse read edit add delete export] list' do
          %w[browse read edit add delete export].each do |action|
            expect(dummy_class.is_crud_authorized?(action, user, Island)).to equal true
          end
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
                                                        'operator' => 'greater_than' }
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
                        "actions" => {}
                      }
                  }
              }
            )

          expect(dummy_class.is_crud_authorized?('browse', user, Island)).to equal true
        end

        it 'should return false when user permission is not allowed' do
          user = { 'id' => 1, 'roleId' => 2 }
          Rails.cache.write('forest.users', {'1' => user})
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
                          "actions" => {}
                        }
                      }
                    }
                  )

          expect(dummy_class.is_crud_authorized?('browse', user, Island)).to equal false
        end
      end
    end
  end
end
