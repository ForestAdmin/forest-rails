module ForestLiana
  class StatGetter < BaseGetter
    attr_accessor :record

    def initialize(resource, params, forest_user)
      @resource = resource
      @params = params
      @user = forest_user

      validate_params
      compute_includes
    end

    def validate_params
      if @params.key?(:aggregator) && !%w[count sum avg max min].include?(@params[:aggregator].downcase)
        raise ForestLiana::Errors::HTTP422Error.new('Invalid aggregate function')
      end
    end

    def get_resource
      super
      @resource.reorder('')
    end
  end
end
