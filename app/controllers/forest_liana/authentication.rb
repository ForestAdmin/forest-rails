require 'uri'

module ForestLiana
  class Authentication < ForestLiana::BaseController
    START_AUTHENTICATION_ROUTE = 'authentication'
    CALLBACK_AUTHENTICATION_ROUTE = 'authentication/callback'
    PUBLIC_ROUTES = [
      "/#{:START_AUTHENTICATION_ROUTE}",
      "/#{:CALLBACK_AUTHENTICATION_ROUTE}",
    ]

    def initialize()
      @authentication_service = ForestLiana::AuthenticationService.new()
      @token_service = ForestLiana::TokenService.new()
    end
  
    def get_callbackUrl(applicationUrl)
        URI.join(applicationUrl, "/forest/#{:CALLBACK_AUTHENTICATION_ROUTE}").to_s
    end

    def check_authSecret(options)
      if !options.auth_secret
        raise ForestLiana::Errors::HTTP500Error.new(
          'Your Forest authSecret seems to be missing. Can you check that you properly set a Forest authSecret in the Forest initializer?'
          )
      end
    end

    def get_and_check_rendering_id(request)
      if request.body.nil? || request.body[:renderingId].nil?
        raise ForestLiana::Errors::HTTP400Error.new(MISSING_RENDERING_ID)
      end

      rendering_id = request.body[:renderingId]

      
      if !(rendering_id.instance_of?(String) || rendering_id.instance_of?(Numeric)) || rendering_id.nan?
        raise ForestLiana::Errors::HTTP400Error.new(INVALID_RENDERING_ID)
      end

      return rendering_id.to_i
    end

    def start_authentication(request) 
      begin
        rendering_id = get_and_check_rendering_id(request);
    
        result = @authentication_service.start_authentication(
          get_callback_url(ENV[:APPLICATION_URL]),
          { 'renderingId' => rendering_id },
        );
    
        redirect_to(result.authorization_url);
      rescue => error
        render json: { errors: [{ status: 400, detail: error.message }] },
          status: :bad_request, serializer: nil
      end
    end

    def authentication_callback(options, request, response) 
      begin
        token = @authentication_service.verify_code_and_generate_token(
          get_callback_url(ENV[:APPLICATION_URL]),
          request.query,
          options,
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
            expires: @token_service.expiration_in_seconds,
            samesite: 'none',
          },
        );

        response_body = {
          tokenData: JWT.decode(token, ForestLiana.auth_secret, true, { algorithm: 'HS256' })
        }

        # The token is sent decoded, because we don't want to share the whole, signed token
        # that is used to authenticate people
        # but the token itself contains interesting values, such as its expiration date
        response_body[:token] = token if !ENV[:APPLICATION_URL].start_with?('https://')

        render json: response_body, status: 200

      rescue => error
        render json: { errors: [{ status: 400, detail: error.message }] },
          status: :bad_request, serializer: nil
      end
    end

  end
end
