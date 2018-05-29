module ForestLiana
  class ResourceGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
      @collection_name = ForestLiana.name_for(@resource)
      @collection = get_collection(@collection_name)
    end

    def perform
      @record = get_resource().eager_load(includes).find(@params[:id])
    end

    def includes
      SchemaUtils.one_associations(@resource)
        .select { |association| SchemaUtils.model_included?(association.klass) }
        .map(&:name)
    end

  end
end
