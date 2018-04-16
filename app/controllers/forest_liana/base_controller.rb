module ForestLiana
  class BaseController < ::ActionController::Base
    skip_before_action :verify_authenticity_token, raise: false
  end
end
