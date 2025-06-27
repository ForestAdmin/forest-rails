module ForestLiana
  module AggregationHelper
    def resolve_field_path(field_param, default_field = 'id')
      if field_param.blank?
        default_field ||= @resource.primary_key || 'id'
        return "#{@resource.table_name}.#{default_field}"
      end

      if field_param.include?(':')
        association, field = field_param.split ':'
        associated_resource = @resource.reflect_on_association(association.to_sym)
        "#{associated_resource.table_name}.#{field}"
      else
        "#{@resource.table_name}.#{field_param}"
      end
    end

    def aggregation_sql(type, field)
      field_path = resolve_field_path(field)

      case type
      when 'sum'
        "SUM(#{field_path})"
      when 'count'
        "COUNT(DISTINCT #{field_path})"
      else
        raise "Unsupported aggregator : #{type}"
      end
    end

    def aggregation_alias(type, field)
      case type
      when 'sum'
        "sum_#{field.downcase}"
      when 'count'
        'count_id'
      else
        raise "Unsupported aggregator : #{type}"
      end
    end
  end
end