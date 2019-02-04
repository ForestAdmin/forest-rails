module ForestLiana
  class PieStatGetter < StatGetter
    attr_accessor :record

    def perform
      if @params[:group_by_field]
        timezone_offset = @params[:timezone].to_i
        conditions = []
        filter_operator = ''

        if @params[:filterType] && @params[:filters]
          filter_operator = " #{@params[:filterType]} ".upcase

          @params[:filters].try(:each) do |filter|
            operator, filter_value = OperatorValueParser.parse(filter[:value])
            conditions <<  OperatorValueParser.get_condition(filter[:field],
              operator, filter_value, @resource, @params[:timezone])
          end
        end

        result = get_resource()
          .eager_load(@includes)
          .where(conditions.join(filter_operator))
          .group(group_by_field)
          .order(order)
          .send(@params[:aggregate].downcase, @params[:aggregate_field])
          .map do |key, value|
            # NOTICE: Display the enum name instead of an integer if it is an
            #         "Enum" field type on old Rails version (before Rails
            #         5.1.3).
            if @resource.respond_to?(:defined_enums) &&
              @resource.defined_enums.has_key?(@params[:group_by_field]) &&
              key.is_a?(Integer)
              key = @resource.defined_enums[@params[:group_by_field]].invert[key]
            elsif @resource.columns_hash[@params[:group_by_field]] &&
              @resource.columns_hash[@params[:group_by_field]].type == :datetime
              key = (key + timezone_offset.hours).strftime('%d/%m/%Y %T')
            end

            { key: key, value: value }
          end

        @record = Model::Stat.new(value: result)
      end
    end

    def group_by_field
      if @params[:group_by_field].include? ':'
        association, field = @params[:group_by_field].split ':'
        resource = @resource.reflect_on_association(association.to_sym)
        "#{resource.table_name}.#{field}"
      else
        "#{@resource.table_name}.#{@params[:group_by_field]}"
      end
    end

    def order
      order = 'DESC'

      # NOTICE: The generated alias for a count is "count_all", for a sum the
      #         alias looks like "sum_#{aggregate_field}"
      if @params[:aggregate].downcase == 'sum'
        field = @params[:aggregate_field].downcase
      else
        field = Rails::VERSION::MAJOR >= 5 || @includes.size > 0 ? 'id' : 'all'
      end
      "#{@params[:aggregate].downcase}_#{field} #{order}"
    end

  end
end
