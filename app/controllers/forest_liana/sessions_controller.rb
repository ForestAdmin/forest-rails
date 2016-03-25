module ForestLiana
  class SessionsController < ActionController::Base

    def create
      fetch_allowed_users
      user = check_user
      token = encode_token(user) if user

      if token
        render json: { token: token }
      else
        render nothing: true, status: 401
      end
    end

    private

    def fetch_allowed_users
      AllowedUsersGetter.new.perform
    end

    def check_user
      ForestLiana.allowed_users.find do |allowed_user|
        allowed_user['email'] == params['email'] &&
          allowed_user['outlines'].include?(params['outlineId']) &&
          BCrypt::Password.new(allowed_user['password']) == params['password']
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
            last_name: user['last_name']
          },
          relationships: {
            outlines: {
              data: [{
                type: 'outlines',
                id: params['outlineId']
              }]
            }
          }
        }
      } , ForestLiana.auth_key, 'HS256')
    end
  end
end
