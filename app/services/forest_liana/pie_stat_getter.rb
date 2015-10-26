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
          .group(@params[:group_by_field])
          .send(@params[:aggregate].downcase, @params[:aggregate_field])
          .map do |k, v|
            { key: k, value: v }
          end

        @record = Stat.new(value: value)
      end
    end

  end
end
