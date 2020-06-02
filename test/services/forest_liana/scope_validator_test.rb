module ForestLiana
  class ScopeValidatorTest < ActiveSupport::TestCase
    test 'Request with aggregated condition filters should be allowed if it matches the scope exactly' do
      scope_validator = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => 'john', 'operator' => 'equal' },
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' }
          ]
        }, [])

      allowed = scope_validator.is_scope_in_request?({
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

    test 'Request with simple condition filter should be allowed if it matches the scope exactly' do
      scope_validator = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'field', 'value' => 'value', 'operator' => 'equal' }
          ]
        }, [])
      allowed = scope_validator.is_scope_in_request?({
        user_id: '1',
        filters: JSON.generate({
          field: 'field', value: 'value', operator: 'equal'
        })
      })
      assert allowed == true
    end

    test 'Request with multiples condition filters should be allowed if it contains the scope ' do
      scope_validator = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => 'doe', 'operator' => 'equal' }
          ]
        }, []
        )
        
      allowed = scope_validator.is_scope_in_request?({
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

    test 'Request with dynamic user values should be allowed if it matches the scope exactly' do
      scope_validator = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => '$currentUser.lastname', 'operator' => 'equal' }
          ],
        }, {
          '1' => { '$currentUser.lastname' => 'john' }
        })

      allowed = scope_validator.is_scope_in_request?({
        user_id: '1',
        filters: JSON.generate({
          'field' => 'name', 'value' => 'john', 'operator' => 'equal'
        })
      })
      assert allowed == true
    end

    test 'Request with multiples aggregation and dynamic values should be allowed if it contains the scope' do
      scope_validator = ForestLiana::ScopeValidator.new({
        'aggregator' => 'or',
        'conditions' => [
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' },
            { 'field' => 'name', 'value' => '$currentUser.lastname', 'operator' => 'equal' }
          ]
        }, {
          '1' => { '$currentUser.lastname' => 'john' }
        })
        
      allowed = scope_validator.is_scope_in_request?({
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

    test 'Request that does not match the expect scope should not be allowed' do
      scope_validator = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => 'john', 'operator' => 'equal' },
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' }
          ]
        }, [])
        
      allowed = scope_validator.is_scope_in_request?({
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

    test 'Request that are missing part of the scope should not be allowed' do
      scope_validator = ForestLiana::ScopeValidator.new({
          'aggregator' => 'and',
          'conditions' => [
            { 'field' => 'name', 'value' => 'john', 'operator' => 'equal' },
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' }
          ]
        }, [])
        
      allowed = scope_validator.is_scope_in_request?({
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

    test 'Request that does not have a top aggregator being "and" should not be allowed' do
      scope_validator = ForestLiana::ScopeValidator.new({
        'aggregator' => 'and',
        'conditions' => [
            { 'field' => 'price', 'value' => '2500', 'operator' => 'equal' },
            { 'field' => 'name', 'value' => '$currentUser.lastname', 'operator' => 'equal' }
          ]
        }, {
          '1' => { '$currentUser.lastname' => 'john' }
        })

      allowed = scope_validator.is_scope_in_request?({
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