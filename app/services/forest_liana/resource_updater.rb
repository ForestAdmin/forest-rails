module ForestLiana
  class ResourceUpdater
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @record = @resource.find(@params[:id])

      if Rails::VERSION::MAJOR == 4
        @record.update_attributes!(resource_params.permit!)
      else
        @record.update_attributes!(resource_params, without_protection: true)
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, @params[:resource]).perform
    end

  end
end
