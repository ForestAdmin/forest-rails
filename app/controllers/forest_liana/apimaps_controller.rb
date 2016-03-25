module ForestLiana
  class ApimapsController < ActionController::Base
    def index
      render nothing: true, status: 204
    end
  end
end
