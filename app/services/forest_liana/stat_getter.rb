module ForestLiana
  class StatGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params, forest_user)
      @resource = resource
      @params = clean_params(params)
      @user = forest_user
      compute_includes
    end

    def get_resource
      super
      @resource.reorder('')
    end

    def clean_params(params)
      params.delete('timezone')
      params.delete('controller')
      params.delete('action')
      params.delete('collection')
      params
    end

  end
end
