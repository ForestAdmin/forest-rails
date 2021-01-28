module ForestLiana
  class AuthorizationGetter
    def self.authenticate(rendering_id, auth_data)
      begin
        route = "/liana/v2/renderings/#{rendering_id.to_s}/authorization"
        headers = { 'forest-token' => auth_data[:forest_token] }
        query_parameters = {}

        response = ForestLiana::ForestApiRequester
          .get(route, query: query_parameters, headers: headers)

        if response.code.to_i == 200
          body = JSON.parse(response.body, :symbolize_names => false)
          user = body['data']['attributes']
          user['id'] = body['data']['id']
          user
        else
            raise "Cannot authorize the user using this forest account. Forest API returned an #{Errors::HTTPErrorHelper.format(response)}"
        end
      rescue
        raise ForestLiana::Errors::HTTP401Error
      end
    end
  end
end
