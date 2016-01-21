module ForestLiana
  class ResourceCreator
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      if Rails::VERSION::MAJOR == 4
        @record = @resource.create!(resource_params.permit!)
      else
        @record = @resource.create!(resource_params, without_protection: true)
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, @params[:resource]).perform
    end

  end
end
