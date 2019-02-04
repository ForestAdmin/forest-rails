module ForestLiana
  class StatGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
      compute_includes()
    end
  end
end
