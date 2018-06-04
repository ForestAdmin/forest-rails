module ForestLiana
  class PermissionsGetter < ForestServerRequester
    def initialize
      @uri = URI.parse("#{forest_url}/liana/v1/permissions")
    end

    def perform
      perform_request
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
        FOREST_LOGGER.error "Cannot retrieve the permissions from the Forest server. Can you check that you properly copied the Forest envSecret in the Liana initializer?"
        []
      else
        FOREST_LOGGER.error "Cannot retrieve the data from the Forest server. An error occured in Forest API."
        []
      end
    end
  end
end
