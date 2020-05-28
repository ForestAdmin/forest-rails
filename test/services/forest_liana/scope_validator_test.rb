module ForestLiana
  class ScopeValidatorTest < ActiveSupport::TestCase
    test 'Validate scope when request contains aggregation and is valid' do
      allowed = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => 'john', 'operator' => 'equal' },
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' }
          ]
        }, []
        ).is_scope_in_request?({
          user_id: '1',
          filters: JSON.generate({
            aggregator: 'and',
            conditions: [
              { field: 'name', value: 'john', operator: 'equal' },
              { field: 'price', value: '2500', operator: 'equal' }              
            ]
          })
        })
      assert allowed == true
    end

    test 'Validate scope when request contains simple condition and is valid' do
      allowed = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'field', 'value' => 'value', 'operator' => 'equal' }
          ]
        }, []
        ).is_scope_in_request?({
          user_id: '1',
          filters: JSON.generate({
            field: 'field', value: 'value', operator: 'equal'
          })
        })
      assert allowed == true
    end

    test 'Validate scope when request contains simple condition with filters and is valid' do
      allowed = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => 'doe', 'operator' => 'equal' }
          ]
        }, []
        ).is_scope_in_request?({
          user_id: '1',
          filters: JSON.generate({
            aggregator: 'and',
            conditions: [
              { field: 'name', value: 'doe', operator: 'equal' },
              { field: 'field2', value: 'value2', operator: 'equal' }              
            ]
          })
        })
      assert allowed == true
    end

    test 'Validate scope when request contains condition with dynamic values and is valid' do
      allowed = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => '$currentUser.lastname', 'operator' => 'equal' }
          ],
        }, {
          '1' => { '$currentUser.lastname' => 'john' }
        }).is_scope_in_request?({
          user_id: '1',
          filters: JSON.generate({
            'field' => 'name', 'value' => 'john', 'operator' => 'equal'
          })
        })
      assert allowed == true
    end

    test 'Validate scope when request contains multiples aggregation with dynamic values and is valid' do
      allowed = ForestLiana::ScopeValidator.new({
        'aggregator' => 'or',
        'conditions' => [
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' },
            { 'field' => 'name', 'value' => '$currentUser.lastname', 'operator' => 'equal' }
          ]
        }, {
          '1' => { '$currentUser.lastname' => 'john' }
        }).is_scope_in_request?({
          user_id: '1',
          filters: JSON.generate({
            aggregator: 'and',
            conditions: [
              { field: 'field', value: 'value', operator: 'equal' },
              { 
                aggregator: 'or',
                conditions: [
                  { field: 'price', value: '2500', operator: 'equal' },
                  { field: 'name', value: 'john', operator: 'equal' }   
                ]
              }
            ]
          })
        })
      assert allowed == true
    end

    test 'Validate scope when request contains aggregation and is invalid' do
      allowed = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => 'john', 'operator' => 'equal' },
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' }
          ]
        }, []
        ).is_scope_in_request?({
          user_id: '1',
          filters: JSON.generate({
            aggregator: 'and',
            conditions: [
              { field: 'name', value: 'definitely_not_john', operator: 'equal' },
              { field: 'price', value: '0', operator: 'equal' }              
            ]
          })
        })
      assert allowed == false
    end

    test 'Validate scope when request is missing some conditions' do
      allowed = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => 'john', 'operator' => 'equal' },
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' }
          ]
        }, []
        ).is_scope_in_request?({
          user_id: '1',
          filters: JSON.generate({
            aggregator: 'and',
            conditions: [
              { field: 'name', value: 'john', operator: 'equal' },
            ]
          })
        })
      assert allowed == false
    end

    test 'Validate scope when request contains valid filters but is ignored by top aggregatpr' do
      allowed = ForestLiana::ScopeValidator.new({
        'aggregator' => 'and',
        'conditions' => [
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' },
            { 'field' => 'name', 'value' => '$currentUser.lastname', 'operator' => 'equal' }
          ]
        }, {
          '1' => { '$currentUser.lastname' => 'john' }
        }).is_scope_in_request?({
          user_id: '1',
          filters: JSON.generate({
            aggregator: 'or',
            conditions: [
              { field: 'field', value: 'value', operator: 'equal' },
              { 
                aggregator: 'and',
                conditions: [
                  { field: 'price', value: '2500', operator: 'equal' },
                  { field: 'name', value: 'john', operator: 'equal' }   
                ]
              }
            ]
          })
        })
      assert allowed == false
    end
  end
end