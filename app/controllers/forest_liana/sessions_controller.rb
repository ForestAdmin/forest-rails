module ForestLiana
  class SessionsController < ActionController::Base

    def create
      @error_message = nil
      @user_class = ForestLiana.user_class_name.constantize rescue nil

      user = check_user
      token = encode_token(user) if user

      if token
        render json: { token: token }, serializer: nil
      else
        if @error_message
          render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
            [{ detail: @error_message }]), status: :unauthorized
        elsif !has_internal_authentication? && ForestLiana.allowed_users.empty?
          render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
            [{ detail: 'Forest cannot retrieve any users for the project ' \
              'you\'re trying to unlock.' }]), status: :unauthorized
        else
          head :unauthorized
        end
      end
    end

    private

    def check_user
      if has_internal_authentication?
        # NOTICE: Use the ForestUser table for authentication.
        user = @user_class.find_by(email: params['email'])
        user if !user.blank? && authenticate_internal_user(user['password_digest'])
      else
        # NOTICE: Query Forest server for authentication.
        fetch_allowed_users

        ForestLiana.allowed_users.find do |allowed_user|
          allowed_user['email'] == params['email'] &&
            BCrypt::Password.new(allowed_user['password']) == params['password']
        end
      end
    end

    def fetch_allowed_users
      AllowedUsersGetter.new.perform(params['renderingId'])
    end

    def has_internal_authentication?
      @user_class && defined? @user_class
    end

    def authenticate_internal_user(password_digest)
      BCrypt::Password.new(password_digest).is_password?(params['password'])
    end

    def encode_token(user)
      if ForestLiana.auth_secret.nil?
        @error_message = "Your Forest auth key seems to be missing. Can " \
          "you check that you properly set a Forest auth key in the " \
          "forest_liana initializer?"
        FOREST_LOGGER.error @error_message
        nil
      else
        JWT.encode({
          exp: Time.now.to_i + 2.weeks.to_i,
          data: {
            id: user['id'],
            type: 'users',
            data: {
              email: user['email'],
              first_name: user['first_name'],
              last_name: user['last_name'],
              teams: user['teams']
            },
            relationships: {
              renderings: {
                data: [{
                  type: 'renderings',
                  id: params['renderingId']
                }]
              }
            }
          }
        }, ForestLiana.auth_secret, 'HS256')
      end
    end
  end
end
