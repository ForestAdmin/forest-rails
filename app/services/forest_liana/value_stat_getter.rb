module ForestLiana
  class ValueStatGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      if @params[:aggregate].try(:downcase) == 'count'
        value = @resource.count
        @record = Stat.new(value: value)
      end
    end

  end
end
