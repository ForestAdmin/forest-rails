module ForestLiana
  class SessionsController < ActionController::Base

    def create
      user = ForestLiana.allowed_users.find do |allowed_user|
        allowed_user['email'] == params['email'] &&
          allowed_user['outlines'].include?(params['outlineId']) &&
          BCrypt::Password.new(allowed_user['password']) == params['password']
      end

      if user
        token = JWT.encode({
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

        render json: { token: token }
      else
        render nothing: true, status: 401
      end
    end
  end
end
