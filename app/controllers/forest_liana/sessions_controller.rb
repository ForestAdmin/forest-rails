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
      # NOTICE: Use the ForestUser table for authentication.
      user_class = ForestLiana.user_class_name.constantize
      if defined? user_class
        user = user_class.find_by(email: params['email'])
        return nil if user.blank?
        if BCrypt::Password.new(user['password_digest']).is_password?(params['password'])
          user
        end
      # NOTICE: Query Forest server for authentication.
      else
        ForestLiana.allowed_users.find do |allowed_user|
          allowed_user['email'] == params['email'] &&
            BCrypt::Password.new(allowed_user['password']) == params['password']
        end
      end
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
