module ForestLiana
  class ActionsController < ForestLiana::BaseController
    def values
      render serializer: nil, json: {}, status: :ok
    end
  end
end
