module ForestLiana
  class LineStatGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
      @populates = {}
    end

    def perform
      value = @resource.unscoped

      @params[:filters].try(:each) do |filter|
        operator, filter_value = OperatorValueParser.parse(filter[:value])
        value = OperatorValueParser.add_where(value, filter[:field], operator,
                                              filter_value, @resource)
      end

      value = value.send(time_range, @params[:group_by_date_field])
      value = value.group(group_by_field || :id) if group_by_field

      value = value.send(@params[:aggregate].downcase, @params[:aggregate_field])
        .map do |k, v|
          if k.kind_of?(Array)
            {
              label: k[0],
              values: {
                key: populate(k[1]),
                value: v
              }
            }
          else
            {
              label: k,
              values: {
                value: v
              }
            }
          end
        end

      @record = Model::Stat.new(value: value)
    end

    private

    def group_by_field
      field_name = @params[:group_by_field]
      association = @resource.reflect_on_association(field_name) if field_name

      if association
        association.foreign_key
      else
        field_name
      end
    end

    def populate(id)
      @populates[id] ||= begin
        field_name = @params[:group_by_field]
        association = @resource.reflect_on_association(field_name)

        if association
          association.klass.find(id)
        else
          id
        end
      end
    end

    def time_range
      "group_by_#{@params[:time_range].try(:downcase) || 'month'}"
    end

  end
end
