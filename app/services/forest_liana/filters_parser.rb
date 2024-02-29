module ForestLiana
  class FiltersParser
    AGGREGATOR_OPERATOR = %w(and or)

    def initialize(filters, resource, timezone, params = nil)
      @filters = filters
      @params = params
      @resource = resource
      @operator_date_parser = OperatorDateIntervalParser.new(timezone)
      @joins = []
    end

    def apply_filters
      return @resource unless @filters

      where = parse_aggregation(@filters)
      return @resource unless where

      @joins.each do |join|
        current_resource = @resource.reflect_on_association(join.name).klass
        current_resource.include(ArelHelpers::Aliases)
        current_resource.aliased_as(join.name) do |aliased_resource|
          @resource = @resource.joins(ArelHelpers.join_association(@resource, join.name, Arel::Nodes::OuterJoin, aliases: [aliased_resource]))
        end
      end

      @resource.where(where)
    end

    def parse_aggregation(node)
      ensure_valid_aggregation(node)

      return parse_condition(node) unless node['aggregator']

      conditions = []
      node['conditions'].each do |condition|
        conditions.push(parse_aggregation(condition))
      end

      operator = parse_aggregation_operator(node['aggregator'])

      conditions.empty? ? nil : "(#{conditions.join(" #{operator} ")})"
    end

    def parse_condition(condition)
      where = parse_condition_without_smart_field(condition)

      field_name = condition['field']

      if ForestLiana::SchemaHelper.is_smart_field?(@resource, field_name)
        schema = ForestLiana.schema_for_resource(@resource)
        field_schema = schema.fields.find do |field|
          field[:field].to_s == field_name
        end

        unless field_schema.try(:[], :filter)
          raise ForestLiana::Errors::NotImplementedMethodError.new("method filter on smart field '#{field_name}' not found")
        end

        return field_schema[:filter].call(condition, where)
      end

      where
    end

    def get_association_field_and_resource(field_name)
      if is_belongs_to(field_name)
        association = field_name.partition(':').first.to_sym
        association_field = field_name.partition(':').last

        unless @resource.reflect_on_association(association)
          raise ForestLiana::Errors::HTTP422Error.new("Association '#{association}' not found")
        end

        current_resource = @resource.reflect_on_association(association).klass

        return association_field, current_resource
      else
        return field_name, @resource
      end
    end

    def parse_condition_without_smart_field(condition)
      ensure_valid_condition(condition)

      operator = condition['operator']
      value = condition['value']
      field_name = condition['field']

      if @operator_date_parser.is_date_operator?(operator)
        condition = @operator_date_parser.get_date_filter(operator, value)
        return "#{parse_field_name(field_name)} #{condition}"
      end

      association_field, current_resource = get_association_field_and_resource(field_name)

      # NOTICE: Set the integer value instead of a string if "enum" type
      # NOTICE: Rails 3 do not have a defined_enums method
      if current_resource.respond_to?(:defined_enums) && current_resource.defined_enums.has_key?(association_field)
        value = current_resource.defined_enums[association_field][value]
      end

      parsed_field = parse_field_name(field_name)
      parsed_operator = parse_operator(operator)
      parsed_value = parse_value(operator, value)
      field_and_operator = "#{parsed_field} #{parsed_operator}"

      sanitize_condition(field_and_operator, operator, parsed_value)
    end

    def parse_aggregation_operator(aggregator_operator)
      unless AGGREGATOR_OPERATOR.include?(aggregator_operator)
        raise_unknown_operator_error(aggregator_operator)
      end

      aggregator_operator.upcase
    end

    def parse_operator(operator)
      case operator
      when 'not'
        'NOT'
      when 'greater_than', 'after'
        '>'
      when 'less_than', 'before'
        '<'
      when 'contains', 'starts_with', 'ends_with'
        'LIKE'
      when 'not_contains'
        'NOT LIKE'
      when 'not_equal'
        '!='
      when 'equal'
        '='
      when 'blank'
        'IS'
      when 'present'
        'IS NOT'
      when 'in'
        'IN'
      else
        raise_unknown_operator_error(operator)
      end
    end

    def parse_value(operator, value)
      case operator
      when 'not', 'greater_than', 'less_than', 'not_equal', 'equal', 'before', 'after'
        value
      when 'contains', 'not_contains'
        "%#{value}%"
      when 'starts_with'
        "#{value}%"
      when 'ends_with'
        "%#{value}"
      when 'in'
        if value.kind_of?(String)
          value.split(',').map { |val| val.strip() }
        else
          value
        end
      when 'present', 'blank'
      else
        raise_unknown_operator_error(operator)
      end
    end

    def parse_field_name(field)
      if is_belongs_to(field)
        current_resource = @resource.reflect_on_association(field.split(':').first.to_sym)&.klass
        raise ForestLiana::Errors::HTTP422Error.new("Field '#{field}' not found") unless current_resource

        association = get_association_name_for_condition(field)
        quoted_table_name = ActiveRecord::Base.connection.quote_column_name(association)
        field_name = field.split(':')[1]
      else
        quoted_table_name = @resource.quoted_table_name
        current_resource = @resource
        field_name = field
      end
      quoted_field_name = ActiveRecord::Base.connection.quote_column_name(field_name)

      column_found = current_resource.columns.find { |column| column.name == field.split(':').last }
      if column_found.nil? && !ForestLiana::SchemaHelper.is_smart_field?(current_resource, field_name)
        raise ForestLiana::Errors::HTTP422Error.new("Field '#{field}' not found")
      end

      "#{quoted_table_name}.#{quoted_field_name}"
    end

    def is_belongs_to(field)
      field.include?(':')
    end

    def get_association_name_for_condition(field)
      field, subfield = field.split(':')

      association = @resource.reflect_on_association(field.to_sym)
      return nil if association.blank?

      @joins << association unless @joins.include? association

      association.name
    end

    # NOTICE: Look for a previous interval condition matching the following:
    #         - If the filter is a simple condition at the root the check is done right away.
    #         - There can't be a previous interval condition if the aggregator is 'or' (no meaning).
    #         - The condition's operator has to be elligible for a previous interval.
    #         - There can't be two previous interval condition.
    def get_previous_interval_condition
      current_previous_interval = nil
      # NOTICE: Leaf condition at root
      unless @filters['aggregator']
        return @filters if @operator_date_parser.has_previous_interval?(@filters['operator'])
      end

      if @filters['aggregator'] === 'and'
        @filters['conditions'].each do |condition|
          # NOTICE: Nested conditions
          return nil if condition['aggregator']

          if @operator_date_parser.has_previous_interval?(condition['operator'])
            # NOTICE: There can't be two previous_interval.
            return nil if current_previous_interval

            current_previous_interval = condition
          end
        end
      end

      current_previous_interval
    end

    def apply_filters_on_previous_interval(previous_condition)
      # Ressource should have already been joined
      where = parse_aggregation_on_previous_interval(@filters, previous_condition)

      @resource.where(where)
    end

    def parse_aggregation_on_previous_interval(node, previous_condition)
      raise_empty_condition_in_filter_error unless node

      return parse_previous_interval_condition(node) unless node['aggregator']

      conditions = []
      node['conditions'].each do |condition|
        if condition == previous_condition
          conditions.push(parse_previous_interval_condition(condition))
        else
          conditions.push(parse_aggregation(condition))
        end
      end

      operator = parse_aggregation_operator(node['aggregator'])

      conditions.empty? ? nil : "(#{conditions.join(" #{operator} ")})"
    end

    def parse_previous_interval_condition(condition)
      raise_empty_condition_in_filter_error unless condition

      parsed_condition = @operator_date_parser.get_date_filter_for_previous_interval(
        condition['operator'],
        condition['value']
      )

      "#{parse_field_name(condition['field'])} #{parsed_condition}"
    end

    def raise_unknown_operator_error(operator)
      raise ForestLiana::Errors::HTTP422Error.new("Unknown provided operator '#{operator}'")
    end

    def raise_empty_condition_in_filter_error
      raise ForestLiana::Errors::HTTP422Error.new('Empty condition in filter')
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

    private

    def prepare_value_for_operator(operator, value)
      # parenthesis around the parsed_value are required to make the `IN` operator work
      operator == 'in' ? "(#{value})" : value
    end

    def sanitize_condition(field_and_operator, operator, parsed_value)
      if Rails::VERSION::MAJOR < 5
        condition_value = prepare_value_for_operator(operator, ActiveRecord::Base.sanitize(parsed_value))
        "#{field_and_operator} #{condition_value}"
        # NOTICE: sanitize method as been removed in Rails 5.1 and sanitize_sql introduced in Rails 5.2.
      elsif Rails::VERSION::MAJOR == 5 && Rails::VERSION::MINOR == 1
        condition_value = prepare_value_for_operator(operator, ActiveRecord::Base.connection.quote(parsed_value))
        "#{field_and_operator} #{condition_value}"
      else
        condition_value = prepare_value_for_operator(operator, '?')
        ActiveRecord::Base.sanitize_sql(["#{field_and_operator} #{condition_value}", parsed_value])
      end
    end
  end
end
