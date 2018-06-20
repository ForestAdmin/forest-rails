module ForestLiana
  class ForestApiRequester
    def perform_request(query_parameters = nil)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.use_ssl = true if forest_api_url.start_with?('https')

      http.start do |client|
        path = get_path(query_parameters)
        request = Net::HTTP::Get.new(path)
        request['Content-Type'] = 'application/json'
        request['forest-secret-key'] = ForestLiana.env_secret
        request['forest-token'] = @forest_token if @forest_token
        response = client.request(request)

        handle_service_response(response)
      end
    end

    def forest_api_url
      ENV['FOREST_URL'] || 'https://api.forestadmin.com';
    end

    def get_path(query_parameters)
      route = @uri.path
      unless query_parameters.nil?
        query = query_parameters
          .collect { |parameter, value| "#{parameter}=#{CGI::escape(value.to_s)}" }.join('&')
        route += "?#{query}"
      end
      route
    end
  end
end
