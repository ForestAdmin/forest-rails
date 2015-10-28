module ForestLiana
  class LineStatGetter
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
          value = value.where("#{filter[:field]} #{operator} '#{filter_value}'")
        end

        value = value.group_by_week(@params[:group_by_date_field])
          .group(group_by_field)
          .send(@params[:aggregate].downcase, @params[:aggregate_field])
          .map do |k, v|
            {
              label: k[0],
              values: {
                key: k[1],
                value: v
              }
            }
          end

        @record = Stat.new(value: value)
      end
    end

    private

    def group_by_field
      field_name = @params[:group_by_field]
      association = @resource.reflect_on_association(field_name)

      if association
        association.foreign_key
      else
        field_name
      end
    end

  end
end
