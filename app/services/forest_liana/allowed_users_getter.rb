module ForestLiana
  class AllowedUsersGetter
    def perform(renderingId)
      uri = URI.parse("#{forest_url}/forest/renderings/#{renderingId}/allowed-users")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if forest_url.start_with?('https')

      begin
        http.start do |client|
          request = Net::HTTP::Get.new(uri.path)
          request['Content-Type'] = 'application/json'
          request['forest-secret-key'] = ForestLiana.secret_key
          response = client.request(request)

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
              "secret key in the forest_liana initializer?"
          else
            FOREST_LOGGER.error "Cannot retrieve any users for the project " \
              "you\'re trying to unlock. An error occured in Forest API."
            []
          end
        end
      rescue => exception
        FOREST_LOGGER.error "Cannot retrieve any users for the project " \
          "you\'re trying to unlock. Forest API seems to be down right now."
      end
    end

    private

    def forest_url
      ENV['FOREST_URL'] || 'https://forestadmin-server.herokuapp.com';
    end
  end
end
