module ForestLiana
  class SessionsController < ForestLiana::BaseController
    def create_with_password
      @error_message = nil
      rendering_id = params['renderingId']
      project_id = params['projectId']
      email = params['email']
      password = params['password']
      two_factor_token = params['token']
      two_factor_registration = params['twoFactorRegistration']

      process_login(
        use_google_authentication: false,
        rendering_id: rendering_id,
        project_id: project_id,
        auth_data: { email: email, password: password },
        two_factor_registration: two_factor_registration,
        two_factor_token: two_factor_token,
      )
    end

    def create_with_google
      @error_message = nil

      forest_token = params['forestToken']
      rendering_id = params['renderingId']
      project_id = params['projectId']
      two_factor_token = params['token']
      two_factor_registration = params['twoFactorRegistration']

      process_login(
        use_google_authentication: true,
        rendering_id: rendering_id,
        project_id: project_id,
        auth_data: { forest_token: forest_token },
        two_factor_registration: two_factor_registration,
        two_factor_token: two_factor_token,
      )
    end

    private

    def process_login(
      use_google_authentication:,
      rendering_id:,
      project_id:,
      auth_data:,
      two_factor_registration:,
      two_factor_token:
    )
      begin
        if two_factor_registration && two_factor_token.nil?
          raise ForestLiana::Errors::HTTP401Error
        end

        # NOTICE: The IP Whitelist is retrieved on any request if it was not retrieved yet, or when
        #         an IP is rejected, to ensure the IP is still rejected (meaning the configuration
        #         on the projects has not changed). To handle the last case, which is rejecting an
        #         IP which was not initaliy rejected, we need periodically refresh the whitelist.
        #         This is done here on the login of any user.
        ForestLiana::IpWhitelist.retrieve

        reponse_data = ForestLiana::LoginHandler.new(
          rendering_id,
          auth_data,
          use_google_authentication,
          two_factor_registration,
          project_id,
          two_factor_token
        ).perform

      rescue ForestLiana::Errors::ExpectedError => error
        error.display_error
        error_data = JSONAPI::Serializer.serialize_errors([{
          status: error.error_code,
          detail: error.message
        }])
        render(serializer: nil, json: error_data, status: error.status)
      rescue StandardError => error
        FOREST_LOGGER.error error
        FOREST_LOGGER.error error.backtrace.join("\n")

        render(serializer: nil, json: nil, status: :internal_server_error)
      else
        render(json: reponse_data, serializer: nil)
      end
    end
  end
end
