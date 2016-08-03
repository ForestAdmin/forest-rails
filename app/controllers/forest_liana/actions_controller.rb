module ForestLiana
  class ActionsController < ForestLiana::ApplicationController
    after_action :log_activities

    def log_activities
      params[:data][:attributes][:ids].each do |record_id|
        collection = params[:data][:attributes][:collection_name]
        action_name = "triggered the action \"#{params[:action].capitalize}\""
        ActivityLogger.new.perform(current_user, action_name, collection,
                            record_id)
      end
      true
    end
  end
end
