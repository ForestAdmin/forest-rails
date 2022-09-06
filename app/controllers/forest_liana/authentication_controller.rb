require 'uri'
require 'json'

module ForestLiana
  class AuthenticationController < ForestLiana::BaseController
    START_AUTHENTICATION_ROUTE = 'authentication'
    CALLBACK_AUTHENTICATION_ROUTE = 'authentication/callback'
    LOGOUT_ROUTE = 'authentication/logout'
    PUBLIC_ROUTES = %W[/#{START_AUTHENTICATION_ROUTE} /#{CALLBACK_AUTHENTICATION_ROUTE} /#{LOGOUT_ROUTE}]

    def initialize
      @authentication_service = ForestLiana::Authentication.new()
    end

    def get_and_check_rendering_id
      if !params.has_key?('renderingId')
        raise ForestLiana::MESSAGES[:SERVER_TRANSACTION][:MISSING_RENDERING_ID]
      end

      rendering_id = params[:renderingId]

      if !(rendering_id.instance_of?(String) || rendering_id.instance_of?(Numeric)) || (rendering_id.instance_of?(Numeric) && rendering_id.nan?)
        raise ForestLiana::MESSAGES[:SERVER_TRANSACTION][:INVALID_RENDERING_ID]
      end

      return rendering_id.to_i
    end

    def start_authentication
      begin
        rendering_id = get_and_check_rendering_id()
        result = @authentication_service.start_authentication({ 'renderingId' => rendering_id })

        render json: { authorizationUrl: result['authorization_url']}, status: 200
      rescue => error
        render json: { errors: [{ status: 500, detail: error.message }] },
          status: :internal_server_error, serializer: nil
      end
    end

    def authentication_callback
      begin
        token = @authentication_service.verify_code_and_generate_token(params)

        response_body = {
          token: token,
          tokenData: JWT.decode(token, ForestLiana.auth_secret, true, { algorithm: 'HS256' })[0]
        }

        render json: response_body, status: 200

      rescue => error
        render json: { errors: [{ status: error.try(:error_code) || 500, detail: error.try(:message) }] },
          status: error.try(:status) || :internal_server_error, serializer: nil
      end
    end

    def logout
      begin
        if cookies.has_key?(:forest_session_token)
          forest_session_token = cookies[:forest_session_token]

          if forest_session_token
            response.set_cookie(
              'forest_session_token',
              {
                value: forest_session_token,
                httponly: true,
                secure: true,
                expires: Time.at(0),
                same_site: :None,
                path: '/'
              },
            )
          end
        end

        render json: {}, status: 204
      rescue => error
        render json: { errors: [{ status: 500, detail: error.message }] },
        status: :internal_server_error, serializer: nil
      end
    end

  end
end
