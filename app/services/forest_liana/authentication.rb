module ForestLiana
  class AuthenticationService
    def initialize()
      @oidc_client_manager_service = ForestLiana::oidc_client_manager_service.new()
      @authorization_finder = ForestLiana::AuthorizationFinder.new()
      @token_service = ForestLiana::TokenService.new()
    end

    private
    def _parse_state(state)
      if !state
        raise ForestLiana::Errors::HTTP400Error.new(INVALID_STATE_MISSING)
      end

      rendering_id

      begin
        parsed_state = JSON.parse(state);
        rendering_id = parsed_state.rendering_id;
      rescue
        raise ForestLiana::Errors::HTTP400Error.new(INVALID_STATE_FORMAT)
      end

      if !rendering_id
        raise ForestLiana::Errors::HTTP400Error.new(INVALID_STATE_RENDERING_ID)
      end

      return rendering_id;
    end

    def start_authentication(redirect_url, state)
      client = @oidc_client_manager_service.get_client_for_callback_url(redirect_url);
  
      # TODOIDC
      authorizationUrl = client.authorizationUrl({
        scope: 'openid email profile',
        state: JSON.stringify(state),
      });
  
      return { 'authorizationUrl' => authorizationUrl };
    
      
    end

    def verify_code_and_generate_token(redirect_url, params, options) 
      client = @oidc_client_manager_service.get_client_for_callback_url(redirect_url)

      rendering_id = _parse_state(params.state)

      # TODOIDC
      token_set = client.callback(
        redirect_url,
        params,
        { state: params.state },
      );

      user = @authorization_finder.authenticate(
        rendering_id,
        options.envSecret,
        nil,
        nil,
        nil,
        token_set.access_token,
      );

      return @token_service.createToken(user, renderingId, options);
    end

  end
end
