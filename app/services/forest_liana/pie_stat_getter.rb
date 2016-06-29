module ForestLiana
  class PieStatGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      if @params[:group_by_field]
        value = @resource

        @params[:filters].try(:each) do |filter|
          operator, filter_value = OperatorValueParser.parse(filter[:value])
          value = OperatorValueParser.add_where(value, filter[:field], operator,
                                                filter_value, @resource)
        end

        # NOTICE: The generated alias for a count is "count_all", for a sum the
        #         alias looks like "sum_#{aggregate_field}"
        field = 'all'
        if @params[:aggregate].downcase == 'sum'
          field = @params[:aggregate_field].downcase
        end

        value = value
          .group(@params[:group_by_field])
          .order("#{@params[:aggregate].downcase}_#{field} DESC")
          .send(@params[:aggregate].downcase, @params[:aggregate_field])
          .map do |k, v|
            { key: k, value: v }
          end

        @record = Model::Stat.new(value: value)
      end
    end

  end
end
