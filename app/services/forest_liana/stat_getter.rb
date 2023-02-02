module ForestLiana
  class StatGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params, forest_user)
      @resource = resource
      @params = params
      @user = forest_user
      compute_includes
    end

    def get_resource
      super
      @resource.reorder('')
    end
  end
end
