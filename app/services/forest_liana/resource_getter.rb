module ForestLiana
  class ResourceGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @record = @resource.eager_load(includes).find(@params[:id])
    end

    def includes
      SchemaUtils.one_associations(@resource)
        .select { |association| SchemaUtils.model_included?(association.klass) }
        .map(&:name)
    end

  end
end
