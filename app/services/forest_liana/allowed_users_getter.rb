module ForestLiana
  class AllowedUsersGetter < UsersGetter
    def initialize(rendering_id)
      super('allowed-users', rendering_id)
    end

    def handle_service_response(response)
      if response.is_a?(Net::HTTPOK)
        body = JSON.parse(response.body)
        ForestLiana.allowed_users = body['data'].map do |d|
          user = d['attributes']
          user['id'] = d['id']

          user
        end
      elsif response.is_a?(Net::HTTPNotFound)
        FOREST_LOGGER.error "Cannot retrieve the project you\'re trying " \
          "to unlock. Can you check that you properly copied the Forest " \
          "env_secret in the forest_liana initializer?"
      else
        FOREST_LOGGER.error "Cannot retrieve any users for the project " \
          "you\'re trying to unlock. An error occured in Forest API."
        []
      end
    end
  end
end
