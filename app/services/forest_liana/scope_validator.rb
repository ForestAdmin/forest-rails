module ForestLiana
  class ScopeValidator
    def initialize(scope_permissions, users_variable_values)
      @scope_filters = scope_permissions
      @users_variable_values = users_variable_values
    end

    def is_scope_in_request?(scope_request)
      begin
        filters = JSON.parse(scope_request[:filters])
      rescue JSON::ParserError
        raise ForestLiana::Errors::HTTP422Error.new('Invalid filters JSON format')
      end
      @computed_scope = compute_condition_filters_from_scope(scope_request[:user_id])

      # NOTICE: Perfom a travel in the request condition filters tree to find the scope
      tagged_scope_filters = get_scope_found_in_request(filters)

      # NOTICE: Permission system always send an aggregator even if there is only one condition
      #         In that case, if the condition is valid, then request was not edited
      return !tagged_scope_filters.nil? if @scope_filters['conditions'].length == 1

      # NOTICE: If there is more than one condition, do a final validation on the condition filters
      return tagged_scope_filters != nil &&
        tagged_scope_filters[:aggregator] == @scope_filters['aggregator'] &&
        tagged_scope_filters[:conditions] &&
        tagged_scope_filters[:conditions].length == @scope_filters['conditions'].length
    end

    private

    def compute_condition_filters_from_scope(user_id)
      computed_condition_filters = @scope_filters.clone
      computed_condition_filters['conditions'].each do |condition|
        if condition.include?('value') && 
          !condition['value'].nil? && 
          condition['value'].start_with?('$') && 
          @users_variable_values.include?(user_id)
          condition['value'] = @users_variable_values[user_id][condition['value']]
        end
      end
      return computed_condition_filters
    end

    def get_scope_found_in_request(filters)
      return nil unless filters
      return search_scope_aggregation(filters)
    end

    def search_scope_aggregation(node)
      ensure_valid_aggregation(node)

      return is_scope_condition?(node) unless node['aggregator']
  
      # NOTICE: Remove conditions that are not from the scope
      filtered_conditions = node['conditions'].map { |condition| 
        search_scope_aggregation(condition)
      }.select { |condition|
        condition
      }

      # NOTICE: If there is only one condition filter left and its current aggregator is
      #         an "and", this condition filter is the searched scope
      if (filtered_conditions.length == 1 && 
        filtered_conditions.first.is_a?(Hash) &&
        filtered_conditions.first.include?(:aggregator) &&
        node['aggregator'] == 'and')
        return filtered_conditions.first
      end

      # NOTICE: Otherwise, validate if the current node is the scope and return nil
      #         if it's not
      return (filtered_conditions.length == @scope_filters['conditions'].length && 
        node['aggregator'] == @scope_filters['aggregator']) ?
        { aggregator: node['aggregator'], conditions: filtered_conditions } :
        nil
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
