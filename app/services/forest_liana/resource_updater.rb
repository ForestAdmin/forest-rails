module ForestLiana
  class ResourceUpdater
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @record = @resource.find(@params[:id])

      if has_strong_parameter
        @record.update_attributes(resource_params)
      else
        @record.update_attributes(resource_params, without_protection: true)
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, @params[:resource], false).perform
    end

    def has_strong_parameter
      @resource.instance_method(:update_attributes!).arity == 1
    end
  end
end
