module ForestLiana
  class AuthorizationGetter
    def self.authenticate(rendering_id, use_google_authentication, auth_data, two_factor_registration)
      begin
        route = "/liana/v2/renderings/#{rendering_id.to_s}/authorization"

        if !use_google_authentication.nil?
          headers = { 'forest-token' => auth_data[:forest_token] }
        elsif !auth_data[:email].nil?
          headers = { 'email' => auth_data[:email], 'password' => auth_data[:password] }
        end

        query_parameters = {}

        unless two_factor_registration.nil?
          query_parameters['two-factor-registration'] = true
        end

        response = ForestLiana::ForestApiRequester
          .get(route, query: query_parameters, headers: headers)

        if response.code.to_i == 200
          body = JSON.parse(response.body, :symbolize_names => false)
          user = body['data']['attributes']
          user['id'] = body['data']['id']
          user
        else
          unless use_google_authentication.nil?
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
