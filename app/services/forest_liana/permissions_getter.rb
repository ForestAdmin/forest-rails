module ForestLiana
  class PermissionsGetter < ForestApiRequester
    def initialize(rendering_id)
      @uri = URI.parse("#{forest_api_url}/liana/v2/permissions")
      @rendering_id = rendering_id
    end

    def perform
      perform_request({ 'renderingId' => @rendering_id })
    rescue => exception
      FOREST_LOGGER.error "Cannot retrieve the permissions for the project you\'re trying to unlock. Forest API seems to be down right now."
      FOREST_LOGGER.error exception
      nil
    end

    private

    def handle_service_response(response)
      if response.is_a?(Net::HTTPOK)
        JSON.parse(response.body)
      elsif response.is_a?(Net::HTTPNotFound) || response.is_a?(Net::HTTPUnprocessableEntity)
        FOREST_LOGGER.error "Cannot retrieve the permissions from the Forest server. Can you check that you properly set up the forest_env_secret?"
        nil
      else
        FOREST_LOGGER.error "Cannot retrieve the data from the Forest server. An error occured in Forest API."
        nil
      end
    end
  end
end
