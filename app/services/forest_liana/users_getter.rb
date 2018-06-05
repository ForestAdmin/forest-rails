module ForestLiana
  class UsersGetter < ForestApiRequester
    def initialize(endpoint, rendering_id)
      @uri = URI.parse("#{forest_api_url}/forest/renderings/#{rendering_id}/#{endpoint}")
    end

    def perform
      perform_request
    rescue => exception
      FOREST_LOGGER.error "Cannot retrieve any users for the project you\'re trying to unlock. Forest API seems to be down right now."
      FOREST_LOGGER.error exception
      nil
    end

    private

    def handle_service_response
      raise 'Abstract class method, this method must be implemented.'
    end
  end
end
