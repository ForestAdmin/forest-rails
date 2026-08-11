class HostCatchAllController < ActionController::Base
  def index
    render json: { caught_by: 'host catch-all' }
  end
end
