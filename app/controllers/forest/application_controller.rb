require 'jwt'

module Forest
  class ApplicationController < ActionController::Base
    before_filter :authenticate_user_from_jwt

    def authenticate_user_from_jwt
      JWT.decode request.headers[:Authorization].split[1],
        Forest.jwt_signing_key
    end

  end
end
