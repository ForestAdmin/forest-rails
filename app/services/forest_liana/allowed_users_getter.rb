module ForestLiana
  class AllowedUsersGetter
    def perform
      uri = URI.parse("#{forest_url}/forest/allowed-users")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if forest_url.start_with?('https')
      http.start do |client|
        request = Net::HTTP::Get.new(uri.path)
        request['Content-Type'] = 'application/json'
        request['forest-secret-key'] = ForestLiana.secret_key
        response = client.request(request)

        if response.is_a?(Net::HTTPOK)
          body = JSON.parse(response.body)['data']
          ForestLiana.allowed_users = body.map do |d|
            user = d['attributes']
            user['id'] = d['id']
            user['outlines'] = d['relationships']['outlines']['data'].map {
              |x| x['id']
            }

            user
          end
        else
          []
        end
      end
    end

    private

    def forest_url
      ENV['FOREST_URL'] || 'https://forestadmin-server.herokuapp.com';
    end
  end
end
