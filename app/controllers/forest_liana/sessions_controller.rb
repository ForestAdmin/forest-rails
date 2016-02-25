module ForestLiana
  class SessionsController < ActionController::Base

    def create
      user = ForestLiana.allowed_users.find do |allowed_user|
        allowed_user['email'] == params['email'] &&
          BCrypt::Password.new(allowed_user['password']) == params['password']
      end

      if user
        token = JWT.encode({
          exp: Time.now.to_i + 2.weeks.to_i,
          data: serialized_user(user)
        } , ForestLiana.auth_key, 'HS256')

        render json: { token: token }
      else
        render nothing: true, status: 401
      end
    end

    private

    def serialized_user(user)
      {
        type: 'users',
        id: user[:id],
        data: {
          email: user[:email],
          first_name: user[:'first-name'] ,
          last_name: user[:'last-name']
        }
      }
    end

  end
end
