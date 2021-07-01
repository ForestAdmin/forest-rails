module ForestLiana
  class StatGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params, forest_user)
      @resource = resource
      @params = params
      @user = forest_user
      compute_includes()
    end
  end
end
