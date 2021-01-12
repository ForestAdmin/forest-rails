require 'uri'
require 'json'

module ForestLiana
  class AuthenticationController < ForestLiana::BaseController
    START_AUTHENTICATION_ROUTE = 'authentication'
    CALLBACK_AUTHENTICATION_ROUTE = 'authentication/callback'
    LOGOUT_ROUTE = 'authentication/logout';
    PUBLIC_ROUTES = [
      "/#{START_AUTHENTICATION_ROUTE}",
      "/#{CALLBACK_AUTHENTICATION_ROUTE}",
      "/#{LOGOUT_ROUTE}",
    ]

    def initialize
      @authentication_service = ForestLiana::Authentication.new()
    end
  
    def get_callback_url
        URI.join(ForestLiana.application_url, "/forest/#{CALLBACK_AUTHENTICATION_ROUTE}").to_s
    rescue => error
      raise "application_url is not valid or not defined" if error.is_a?(ArgumentError)
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
        callback_url = get_callback_url()

        result = @authentication_service.start_authentication(
          callback_url,
          { 'renderingId' => rendering_id },
        )

        render json: { authorizationUrl: result['authorization_url']}, status: 200
      rescue => error
        render json: { errors: [{ status: 500, detail: error.message }] },
          status: :internal_server_error, serializer: nil
      end
    end

    def authentication_callback
      begin
        callback_url = get_callback_url()

        token = @authentication_service.verify_code_and_generate_token(
          callback_url,
          params,
        )
    
        response.set_cookie(
          'forest_session_token',
          {
            value: token,
            httponly: true,
            secure: true,
            expires: ForestLiana::Token.expiration_in_days,
            samesite: 'none',
            path: '/'
          },
        )

        response_body = {
          tokenData: JWT.decode(token, ForestLiana.auth_secret, true, { algorithm: 'HS256' })[0]
        }

        # The token is sent decoded, because we don't want to share the whole, signed token
        # that is used to authenticate people
        # but the token itself contains interesting values, such as its expiration date
        response_body[:token] = token if !ForestLiana.application_url.start_with?('https://')

        render json: response_body, status: 200

      rescue => error
        render json: { errors: [{ status: 500, detail: error.message }] },
          status: :internal_server_error, serializer: nil
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
                samesite: 'none',
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
