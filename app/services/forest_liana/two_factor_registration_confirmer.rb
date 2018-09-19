module ForestLiana
  class TwoFactorRegistrationConfirmer
    def initialize(
      project_id,
      use_google_authentication,
      auth_data
    )
      @project_id = project_id
      @use_google_authentication = use_google_authentication
      @auth_data = auth_data
    end

    def perform
      begin
        body_data = { 'useGoogleAuthentication' => @use_google_authentication }

        if @use_google_authentication
          body_data['forestToken'] = @auth_data[:forest_token]
        else
          body_data['email'] = @auth_data[:email]
        end

        response = ForestLiana::ForestApiRequester.post(
          "/liana/v2/projects/#{@project_id}/two-factor-registration-confirm",
          body: body_data,
        )

        unless response.is_a?(Net::HTTPOK)
          raise "Cannot retrieve the data from the Forest server. Forest API returned an #{ForestLiana::Errors::HTTPErrorHelper.format(response)}"
        end
      rescue
        raise ForestLiana::Errors::HTTP401Error
      end
    end
  end
end
