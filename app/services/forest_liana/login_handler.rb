require 'rotp'

module ForestLiana
  class LoginHandler
    def initialize(
      rendering_id,
      auth_data,
      use_google_authentication,
      two_factor_registration,
      project_id,
      two_factor_token
    )
      @rendering_id = rendering_id
      @auth_data = auth_data
      @use_google_authentication = use_google_authentication
      @two_factor_registration = two_factor_registration
      @project_id = project_id
      @two_factor_token = two_factor_token
    end

    def perform
      user = ForestLiana::AuthorizationGetter.new(
        @rendering_id,
        @use_google_authentication,
        @auth_data,
        @two_factor_registration
      ).perform

      if user['two_factor_authentication_enabled']
        if !@two_factor_token.nil?
          if is_two_factor_token_valid(user, @two_factor_token)
            ForestLiana::TwoFactorRegistrationConfirmer
              .new(@project_id, @use_google_authentication, @auth_data)
              .perform

            return { 'token' => create_token(user, @rendering_id) }
          else
            raise ForestLiana::Errors::HTTP401Error.new('Your token is invalid, please try again.')
          end
        else
          return get_two_factor_response(user)
        end
      end

      return { token: create_token(user, @rendering_id) }
    end

    private

    def check_two_factor_secret_salt
      if ENV['FOREST_2FA_SECRET_SALT'].nil?
        FOREST_LOGGER.error 'Cannot use the two factor authentication because the environment variable "FOREST_2FA_SECRET_SALT" is not set.'
        FOREST_LOGGER.error 'You can generate it using this command: `$ openssl rand -hex 10`'

        raise Errors::HTTP401Error.new('Invalid 2FA configuration, please ask more information to your admin')
      end

      if ENV['FOREST_2FA_SECRET_SALT'].length != 20
        FOREST_LOGGER.error 'The FOREST_2FA_SECRET_SALT environment variable must be 20 characters long.'
        FOREST_LOGGER.error 'You can generate it using this command: `$ openssl rand -hex 10`'

        raise ForestLiana::Errors::HTTP401Error.new('Invalid 2FA configuration, please ask more information to your admin')
      end
    end

    def get_two_factor_response(user)
      check_two_factor_secret_salt

      return { 'twoFactorAuthenticationEnabled' => true } if user['two_factor_authentication_active']

      two_factor_authentication_secret = user['two_factor_authentication_secret']
      user_secret = ForestLiana::UserSecretCreator
        .new(two_factor_authentication_secret, ENV['FOREST_2FA_SECRET_SALT'])
        .perform

      {
        twoFactorAuthenticationEnabled: true,
        userSecret: user_secret,
      }
    end

    def is_two_factor_token_valid(user, two_factor_token)
      check_two_factor_secret_salt

      two_factor_authentication_secret = user['two_factor_authentication_secret']

      user_secret = ForestLiana::UserSecretCreator
        .new(two_factor_authentication_secret, ENV['FOREST_2FA_SECRET_SALT'])
        .perform

      totp = ROTP::TOTP.new(user_secret)
      totp.verify(two_factor_token)
    end

    def create_token(user, rendering_id)
      JWT.encode({
        id: user['id'],
        email: user['email'],
        first_name: user['first_name'],
        last_name: user['last_name'],
        team: user['teams'][0],
        rendering_id: rendering_id,
        exp: Time.now.to_i + 2.weeks.to_i
      }, ForestLiana.auth_secret, 'HS256')
    end
  end
end
