module ForestLiana
  class PieStatGetter < StatGetter
    attr_accessor :record

    def perform
      if @params[:groupByFieldName]
        timezone_offset = @params[:timezone].to_i
        resource = optimize_record_loading(@resource, get_resource)

        filters = ForestLiana::ScopeManager.append_scope_for_user(@params[:filter], @user, @resource.name, @params['contextVariables'])

        unless filters.blank?
          resource = FiltersParser.new(filters, resource, @params[:timezone], @params).apply_filters
        end

        result = resource
          .group(groupByFieldName)
          .order(order)
          .send(@params[:aggregator].downcase, @params[:aggregateFieldName])
          .map do |key, value|
            # NOTICE: Display the enum name instead of an integer if it is an
            #         "Enum" field type on old Rails version (before Rails
            #         5.1.3).
            if @resource.respond_to?(:defined_enums) &&
              @resource.defined_enums.has_key?(@params[:groupByFieldName]) &&
              key.is_a?(Integer)
              key = @resource.defined_enums[@params[:groupByFieldName]].invert[key]
            elsif @resource.columns_hash[@params[:groupByFieldName]] &&
              @resource.columns_hash[@params[:groupByFieldName]].type == :datetime
              key = (key + timezone_offset.hours).strftime('%d/%m/%Y %T')
            end

            { key: key, value: value }
          end

        @record = Model::Stat.new(value: result)
      end
    end

    def groupByFieldName
      if @params[:groupByFieldName].include? ':'
        association, field = @params[:groupByFieldName].split ':'
        resource = @resource.reflect_on_association(association.to_sym)
        "#{resource.table_name}.#{field}"
      else
        "#{@resource.table_name}.#{@params[:groupByFieldName]}"
      end
    end

    def order
      order = 'DESC'

      # NOTICE: The generated alias for a count is "count_all", for a sum the
      #         alias looks like "sum_#{aggregateFieldName}"
      if @params[:aggregator].downcase == 'sum'
        field = @params[:aggregateFieldName].downcase
      else
        # `count_id` is required only for rails v5
        field = Rails::VERSION::MAJOR == 5 || @includes.size > 0 ? 'id' : 'all'
      end
      "#{@params[:aggregator].downcase}_#{field} #{order}"
    end

  end
end
