module ForestLiana
  class ScopeValidator
    def initialize(scope_permissions, scope_values)
      @scope_filters = scope_permissions
      @dynamic_scope_variables = scope_values
    end

    def is_scope_in_request?(scope_request)
      begin
        filters = JSON.parse(scope_request[:filters])
      rescue JSON::ParserError
        raise ForestLiana::Errors::HTTP422Error.new('Invalid filters JSON format')
      end
      @computed_scope = compute_condition_filters_from_scope(scope_request[:user_id])
      tagged_scope_filters = validate(filters)
      return tagged_scope_filters != nil if @scope_filters['conditions'].length == 1
      return tagged_scope_filters != nil && tagged_scope_filters[:aggregator] == @scope_filters['aggregator'] && tagged_scope_filters[:conditions] && tagged_scope_filters[:conditions].length == @scope_filters['conditions'].length
    end

    private

    def compute_condition_filters_from_scope(user_id)
      computed_condition_filters = @scope_filters.clone
      computed_condition_filters['conditions'].each do |condition|
        if condition.include?('value') && condition['value'].start_with?('$') && @dynamic_scope_variables.include?(user_id)
          condition['value'] = @dynamic_scope_variables[user_id][condition['value']]
        end
      end
      return computed_condition_filters
    end

    def validate(filters)
      return nil unless filters
      return search_scope_aggregation(filters)
    end

    def search_scope_aggregation(node)
      ensure_valid_aggregation(node)
      return is_scope_condition?(node) unless node['aggregator']
      filtered_conditions = node['conditions'].map { |condition| 
        search_scope_aggregation(condition)
      }.select { |condition|
        condition
      }

      if (filtered_conditions.length === 1 && filtered_conditions.first.is_a?(Hash) && filtered_conditions.first.include?(:aggregator) && node['aggregator'] == 'and')
        return filtered_conditions.first
      end

      return filtered_conditions.length === @scope_filters['conditions'].length && (node['aggregator'] == @scope_filters['aggregator']) ? { aggregator: node['aggregator'], conditions: filtered_conditions } : nil
    end


    def is_scope_condition?(condition)
      ensure_valid_condition(condition)
      return @computed_scope['conditions'].include?(condition)
    end

    def ensure_valid_aggregation(node)
      raise ForestLiana::Errors::HTTP422Error.new('Filters cannot be a raw value') unless node.is_a?(Hash)
      raise_empty_condition_in_filter_error if node.empty?
    end

    def ensure_valid_condition(condition)
      raise_empty_condition_in_filter_error if condition.empty?
      raise ForestLiana::Errors::HTTP422Error.new('Condition cannot be a raw value') unless condition.is_a?(Hash)
      unless condition['field'].is_a?(String) and condition['operator'].is_a?(String)
        raise ForestLiana::Errors::HTTP422Error.new('Invalid condition format')
      end
    end
  end
end
