module ForestLiana
  class GoogleAuthorizedUserGetter < UsersGetter
    def initialize(rendering_id, forest_token)
      @forest_token = forest_token
      super('google-authorization', rendering_id)
    end

    def handle_service_response(response)
      if response.is_a?(Net::HTTPOK)
        body = JSON.parse(response.body)
        body['data']['attributes']
      elsif response.is_a?(Net::HTTPNotFound)
        FOREST_LOGGER.error "Cannot retrieve the project you\'re trying " \
          "to unlock. Can you check that you properly copied the Forest " \
          "env_secret in the forest_liana initializer?"
        nil
      elsif response.is_a?(Net::HTTPUnauthorized)
        FOREST_LOGGER.error "Cannot retrieve the user for the project " \
          "you\'re trying to unlock. The google user account seems invalid."
        nil
      else
        FOREST_LOGGER.error "Cannot retrieve the user for the project " \
          "you\'re trying to unlock. An error occured in Forest API."
        nil
      end
    end
  end
end
