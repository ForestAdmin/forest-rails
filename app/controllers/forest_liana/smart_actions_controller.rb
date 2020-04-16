module ForestLiana
  class SmartActionsController < ForestLiana::ApplicationController
    if Rails::VERSION::MAJOR < 4
      before_filter :check_permission_for_smart_route
    else
      before_action :check_permission_for_smart_route
    end
  end
end
