module ForestLiana
  class FiltersParser
    AGGREGATOR_OPERATOR = %w(and or)

    def initialize(filters, resource, timezone)
      begin
        @filters = JSON.parse(filters)
      rescue JSON::ParserError
        raise ForestLiana::Errors::HTTP422Error.new('Invalid filters JSON format')
      end

      @resource = resource
      @operator_date_interval_parser = OperatorDateIntervalParser.new(timezone)
      @joins = []
    end

    def apply_filters
      return @resource unless @filters

      where = parse_aggregation(@filters)
      return @resource unless where

      @joins.each do |join|
        @resource = @resource.joins(ArelHelpers.join_association(@resource, join, Arel::Nodes::OuterJoin))
      end

      @resource.where(where)
    end

    def parse_aggregation(node)
      raise_empty_condition_in_filter_error if node.empty?

      return parse_condition(node) unless node['aggregator']

      conditions = []
      node['conditions'].each do |condition|
        conditions.push(parse_aggregation(condition))
      end

      operator = parse_aggregation_operator(node['aggregator'])

      conditions.empty? ? nil : "(#{conditions.join(" #{operator} ")})"
    end

    def parse_condition(condition)
      raise_empty_condition_in_filter_error unless condition

      operator = condition['operator']
      value = condition['value']
      field = condition['field']

      if @operator_date_interval_parser.is_date_interval_operator(operator)
        condition = @operator_date_interval_parser.get_interval_date_filter(operator, value)
        return "#{parse_field_name(field)} #{condition}"
      end

      if is_belongs_to(field)
        association = field.partition(':').first.to_sym
        association_field = field.partition(':').last

        unless @resource.reflect_on_association(association)
          raise ForestLiana::Errors::HTTP422Error.new("Association '#{association}' not found")
        end

        current_resource = @resource.reflect_on_association(association).klass
      else
        association_field = field
        current_resource = @resource
      end

      # NOTICE: Set the integer value instead of a string if "enum" type
      # NOTICE: Rails 3 do not have a defined_enums method
      if current_resource.respond_to?(:defined_enums) && current_resource.defined_enums.has_key?(association_field)
        value = current_resource.defined_enums[association_field][value]
      end

      if Rails::VERSION::MAJOR >= 5
        ActiveRecord::Base.sanitize_sql([
          "#{parse_field_name(field)} #{parse_operator(operator)}?",
          parse_value(operator, value)
        ])
      else
        "#{parse_field_name(field)} #{parse_operator(operator)} #{ActiveRecord::Base.sanitize(parse_value(operator, value))}"
      end
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
        'NOT_LIKE'
      when 'not_equal'
        '!='
      when 'present'
        'IS NOT NULL'
      when 'equal'
        '='
      when 'blank'
        'IS NULL'
      else
        raise_unknown_operator_error(operator)
      end
    end

    def parse_value(operator, value)
      case operator
      when 'not'
        value
      when'greater_than', 'less_than', 'not_equal', 'equal', 'before', 'after'
        "#{value}"
      when 'contains', 'not_contains'
        "%#{value}%"
      when 'starts_with'
        "#{value}%"
      when 'ends_with'
        "%#{value}"
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
        quoted_field_name = ActiveRecord::Base.connection.quote_column_name(field.split(':')[1])
      else
        quoted_table_name = @resource.quoted_table_name
        quoted_field_name = ActiveRecord::Base.connection.quote_column_name(field)
        current_resource = @resource
      end

      column_found = current_resource.columns.find { |column| column.name == field.split(':').last }

      if column_found.nil?
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

      @joins << association.name unless @joins.include? association.name

      tables_associated_to_relations_name =
        ForestLiana::QueryHelper.get_tables_associated_to_relations_name(@resource)
      association_name = association.name.to_s
      association_name_pluralized = association_name.pluralize

      if [association_name, association_name_pluralized].include? association.table_name
        # NOTICE: Default case. When the belongsTo association name and the referenced table name
        #         are identical.
        association.table_name
      else
        # NOTICE: When the the belongsTo association name and the referenced table name are not
        #         identical. Format with the ActiveRecord query generator style.
        relations_on_this_table = tables_associated_to_relations_name[association.table_name]
        has_several_associations_to_the_table_and_is_not_first_one =
          !relations_on_this_table.nil? && relations_on_this_table.size > 1 &&
          relations_on_this_table.find_index(association.name) > 0

        if has_several_associations_to_the_table_and_is_not_first_one
          "#{association_name_pluralized}_#{@resource.table_name}"
        else
          association.table_name
        end
      end
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
        return @filters if @operator_date_interval_parser.has_previous_interval(@filters['operator'])
      end

      if @filters['aggregator'] === 'and'
        @filters['conditions'].each do |condition|
          # NOTICE: Nested conditions
          return nil if condition['aggregator']

          if @operator_date_interval_parser.has_previous_interval(condition['operator'])
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

      parsed_condition = @operator_date_interval_parser.get_interval_date_filter_for_previous_interval(
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
  end
end
