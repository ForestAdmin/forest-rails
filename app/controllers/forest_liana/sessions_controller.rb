module ForestLiana
  class SessionsController < ActionController::Base

    def create
      fetch_allowed_users
      user = check_user
      token = encode_token(user) if user

      if token
        render json: { token: token }, serializer: nil
      else
        head :unauthorized
      end
    end

    private

    def fetch_allowed_users
      AllowedUsersGetter.new.perform(params['renderingId'])
    end

    def check_user
      user_class = ForestLiana.user_class_name.constantize rescue nil

      if user_class && defined? user_class
        # NOTICE: Use the ForestUser table for authentication.
        user = user_class.find_by(email: params['email'])
        user if !user.blank? && authenticate_internal_user(user['password_digest'])
      else
        # NOTICE: Query Forest server for authentication.
        ForestLiana.allowed_users.find do |allowed_user|
          allowed_user['email'] == params['email'] &&
            BCrypt::Password.new(allowed_user['password']) == params['password']
        end
      end
    end

    def authenticate_internal_user(password_digest)
      BCrypt::Password.new(password_digest).is_password?(params['password'])
    end

    def encode_token(user)
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
      } , ForestLiana.auth_key, 'HS256')
    end
  end
end
