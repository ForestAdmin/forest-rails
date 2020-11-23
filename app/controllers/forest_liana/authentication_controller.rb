require 'uri'
require 'json'

module ForestLiana
  class AuthenticationController < ForestLiana::BaseController
    START_AUTHENTICATION_ROUTE = 'authentication'
    CALLBACK_AUTHENTICATION_ROUTE = 'authentication/callback'
    PUBLIC_ROUTES = [
      "/#{START_AUTHENTICATION_ROUTE}",
      "/#{CALLBACK_AUTHENTICATION_ROUTE}",
    ]

    def initialize
      @authentication_service = ForestLiana::Authentication.new()
      @token_service = ForestLiana::Token.new()
    end
  
    def get_callback_url
        URI.join(ForestLiana.application_url, "/forest/#{CALLBACK_AUTHENTICATION_ROUTE}").to_s
    end

    def get_and_check_rendering_id
      if !params.has_key?(:renderingId)
        
        raise ForestLiana::Errors::HTTP500Error.new(MISSING_RENDERING_ID)
      end

      rendering_id = params[:renderingId]
      
      if !(rendering_id.instance_of?(String) || rendering_id.instance_of?(Numeric)) || (rendering_id.instance_of?(Numeric) && rendering_id.nan?)
        raise ForestLiana::Errors::HTTP500Error.new(INVALID_RENDERING_ID)
      end

      return rendering_id.to_i
    end

    def start_authentication 
      begin
        rendering_id = get_and_check_rendering_id()

        result = @authentication_service.start_authentication(
          get_callback_url(),
          { 'renderingId' => rendering_id },
        );
        
        redirect_to(result['authorization_url'])
      rescue => error
        render json: { errors: [{ status: 500, detail: error.message }] },
          status: :internal_server_error, serializer: nil
      end
    end

    def authentication_callback
      begin
        token = @authentication_service.verify_code_and_generate_token(
          get_callback_url(),
          params,
        )
    
        # Cookies with secure=true & sameSite:'none' will only work
        # on localhost or https
        # These are the only 2 supported situations for agents, that's
        # why the token is not returned inside the body
        response.set_cookie(
          'forest_session_token',
          {
            value: token,
            httponly: true,
            secure: true,
            expires: @token_service.expiration_in_days,
            samesite: 'none',
          },
        );

        response_body = {
          tokenData: JWT.decode(token, ForestLiana.auth_secret, true, { algorithm: 'HS256' })
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

  end
end
