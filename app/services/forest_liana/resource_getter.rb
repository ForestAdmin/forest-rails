module ForestLiana
  class ResourceGetter < BaseGetter
    attr_accessor :record
    attr_reader :collection

    def initialize(resource, params)
      @resource = resource
      @params = params
      @collection_name = ForestLiana.name_for(@resource)
      @collection = get_collection(@collection_name)
      compute_includes()
    end

    def perform
      @record = get_resource().eager_load(@includes).find(@params[:id])
    end
  end
end
