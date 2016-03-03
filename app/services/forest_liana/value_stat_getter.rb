module ForestLiana
  class ValueStatGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      return if @params[:aggregate].blank?
      value = @resource

      @params[:filters].try(:each) do |filter|
        operator, filter_value = OperatorValueParser.parse(filter[:value])
        value = OperatorValueParser.add_where(value, filter[:field], operator,
                                              filter_value)
      end

      @record = Model::Stat.new(value: count(value))
    end

    private

    def count(value)
      uniq = @params[:aggregate].downcase == 'count'

      if Rails::VERSION::MAJOR == 4
        value = value.uniq if uniq
        value.send(@params[:aggregate].downcase, aggregate_field)
      else
        value.send(@params[:aggregate].downcase, aggregate_field,
                   distinct: uniq)
      end
    end

    def aggregate_field
      @params[:aggregate_field] || :id
    end

  end
end
