module ForestLiana
  class AuthorizationGetter
    def self.authenticate(rendering_id, auth_data)
      begin
        route = "/liana/v2/renderings/#{rendering_id.to_s}/authorization"
        headers = { 'forest-token' => auth_data[:forest_token] }

        response = ForestLiana::ForestApiRequester
          .get(route, query: {}, headers: headers)

        if response.code.to_i == 200
          body = JSON.parse(response.body, :symbolize_names => false)
          user = body['data']['attributes']
          user['id'] = body['data']['id']
          user
        else
          raise generate_authentication_error response
        end
      end
    end

    private
    def self.generate_authentication_error(error)
      case error[:message]
      when ForestLiana::MESSAGES[:SERVER_TRANSACTION][:SECRET_AND_RENDERINGID_INCONSISTENT]
        return ForestLiana::Errors::InconsistentSecretAndRenderingError.new()
      when ForestLiana::MESSAGES[:SERVER_TRANSACTION][:SECRET_NOT_FOUND]
        return ForestLiana::Errors::SecretNotFoundError.new()
      else
      end

      serverError = error[:jse_cause][:response][:body][:errors][0] || nil

      if !serverError.nil? && serverError[:name] == ForestLiana::MESSAGES[:SERVER_TRANSACTION][:names][:TWO_FACTOR_AUTHENTICATION_REQUIRED]
        return ForestLiana::Errors::TwoFactorAuthenticationRequiredError.new()
      end

      return StandardError.new(error)
    end
  end
end
