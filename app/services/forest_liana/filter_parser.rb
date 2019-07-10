module ForestLiana
  class FilterParser
    AGGREGATOR_OPERATOR = %w(and or)

    def initialize(filters, resource)
      @filters = JSON.parse(filters)
      @resource = resource
      @joins = []
    end

    def apply_filters
      return @resource unless @filters

      where = parse_aggregator(@filters)
      return @resource unless where

      @joins.each do |join|
        @resource = @resource.joins(ArelHelpers.join_association(@resource, join, Arel::Nodes::OuterJoin))
      end

      @resource.where(where)
    end

    def parse_aggregator(node)
      return parse_condition(node) unless node['aggregator']

      conditions = []
      node['conditions'].each do |condition|
        conditions.push(parse_aggregator(condition))
      end

      operator = parse_aggregator_operator(node['aggregator'])

      conditions.empty? ? nil : "(#{conditions.join(" #{operator} ")})"
    end

    def parse_condition(condition)
      operator = condition['operator']
      value = condition['value']
      field = condition['field']
      ActiveRecord::Base.sanitize_sql([
        "#{parse_field_name(field)} #{parse_operator(operator)}?",
        parse_value(operator, value)
      ])
    end

    def parse_aggregator_operator(aggregator_operator)
      unless AGGREGATOR_OPERATOR.include?(aggregator_operator)
        raise ForestLiana::Errors::HTTP422Error.new("Unknown provided operator '#{operator}'")
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
        raise ForestLiana::Errors::HTTP422Error.new("Unknown provided operator '#{operator}'")
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
        raise ForestLiana::Errors::HTTP422Error.new("Unknown provided operator '#{operator}'")
      end
    end

    def parse_field_name(field)
      if is_belongs_to(field)
        association = get_association_name_for_condition(field)
        quoted_table_name = ActiveRecord::Base.connection.quote_column_name(association)
        quoted_field_name = ActiveRecord::Base.connection.quote_column_name(field.split(':')[1])
      else
        quoted_table_name = @resource.quoted_table_name
        quoted_field_name = ActiveRecord::Base.connection.quote_column_name(field)
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

      @joins << association.name unless @joins.contains association.name

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
  end
end
