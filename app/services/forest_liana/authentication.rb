module ForestLiana
  class Authentication
    def initialize()
      @oidc_client_manager_service = ForestLiana::OidcClientManager.new()
      @authorization_getter = ForestLiana::AuthorizationGetter.new()
      @token_service = ForestLiana::Token.new()
    end

    def _parse_state(state)
      if !state
        raise ForestLiana::Errors::HTTP500Error.new('INVALID_STATE_MISSING')
      end

      rendering_id = nil

      begin
        parsed_state = JSON.parse(state.gsub("'",'"').gsub('=>',':'))
        rendering_id = parsed_state["renderingId"].to_s
      rescue
        raise ForestLiana::Errors::HTTP500Error.new('INVALID_STATE_FORMAT')
      end

      if rendering_id.nil?
        raise ForestLiana::Errors::HTTP500Error.new('INVALID_STATE_RENDERING_ID')
      end

      return rendering_id
    end

    def start_authentication(redirect_url, state)
      client = @oidc_client_manager_service.get_client_for_callback_url(redirect_url);
  
      # TODOIDC
      authorization_url = client.authorization_uri({
        scope: 'openid email profile',
        state: state.to_s,
      });
  
      return { 'authorization_url' => authorization_url };
    
      
    end

    def verify_code_and_generate_token(redirect_url, params) 
      client = @oidc_client_manager_service.get_client_for_callback_url(redirect_url)
      rendering_id = _parse_state(params['state'])
      client.authorization_code = params['code']

      # TODOIDC
      OpenIDConnect.http_config do |config|
        config.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      access_token_instance = client.access_token! 'none'

      user = @authorization_getter.authenticate(
        rendering_id,
        true,
        { :forest_token => access_token_instance.instance_variable_get(:@access_token) },
        nil,
      );

      return @token_service.create_token(user, rendering_id)
    end

  end
end
