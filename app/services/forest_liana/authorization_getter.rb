module ForestLiana
  class AuthorizationGetter
    def initialize(rendering_id, use_google_authentication, auth_data, two_factor_registration)
      @rendering_id = rendering_id
      @use_google_authentication = use_google_authentication
      @auth_data = auth_data
      @two_factor_registration = two_factor_registration

      @route = "/liana/v2/renderings/#{rendering_id}"
      @route += use_google_authentication ? "/google-authorization" : "/authorization"
    end

    def perform
      begin
        if @use_google_authentication
          headers = { 'forest-token' => @auth_data[:forest_token] }
        else
          headers = { 'email' => @auth_data[:email], 'password' => @auth_data[:password] }
        end

        query_parameters = { 'renderingId' => @rendering_id }

        if @two_factor_registration
          query_parameters['two-factor-registration'] = true
        end

        response = ForestLiana::ForestApiRequester
          .get(@route, query: query_parameters, headers: headers)

        if response.is_a?(Net::HTTPOK)
          body = JSON.parse(response.body)
          user = body['data']['attributes']
          user['id'] = body['data']['id']
          user
        else
          if @use_google_authentication
            raise "Cannot authorize the user using this google account. Forest API returned an #{Errors::HTTPErrorHelper.format(response)}"
          else
            raise "Cannot authorize the user using this email/password. Forest API returned an #{Errors::HTTPErrorHelper.format(response)}"
          end
        end
      rescue
        raise ForestLiana::Errors::HTTP401Error
      end
    end
  end
end
