module ForestLiana
  class Authentication
    def start_authentication(state)
      client = ForestLiana::OidcClientManager.get_client()

      authorization_url = client.authorization_uri({
        scope: 'openid email profile',
        state: state.to_s,
      })

      { 'authorization_url' => authorization_url }
    end

    def verify_code_and_generate_token(params)
      client = ForestLiana::OidcClientManager.get_client()

      rendering_id = parse_state(params['state'])
      client.authorization_code = params['code']

      if Rails.env.development? || Rails.env.test?
        OpenIDConnect.http_config do |config|
          config.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end
      access_token_instance = client.access_token! 'none'

      user = ForestLiana::AuthorizationGetter.authenticate(
        rendering_id,
        { :forest_token => access_token_instance.instance_variable_get(:@access_token) },
      )

      return ForestLiana::Token.create_token(user, rendering_id)
    end

    private
    def parse_state(state)
      unless state
        raise ForestLiana::MESSAGES[:SERVER_TRANSACTION][:INVALID_STATE_MISSING]
      end

      begin
        parsed_state = JSON.parse(state.gsub("'",'"').gsub('=>',':'))
        rendering_id = parsed_state["renderingId"].to_s
      rescue
        raise ForestLiana::MESSAGES[:SERVER_TRANSACTION][:INVALID_STATE_FORMAT]
      end

      if rendering_id.nil?
        raise ForestLiana::MESSAGES[:SERVER_TRANSACTION][:INVALID_STATE_RENDERING_ID]
      end

      return rendering_id
    end
  end
end
