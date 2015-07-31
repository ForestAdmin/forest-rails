module ForestLiana
  class ResourceGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @record = @resource.find(@params[:id])
    end

  end
end
