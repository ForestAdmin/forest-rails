module ForestLiana
  class StatGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    private

    def includes
      SchemaUtils.one_associations(@resource)
        .select { |association| SchemaUtils.model_included?(association.klass) }
        .map(&:name)
    end
  end
end
