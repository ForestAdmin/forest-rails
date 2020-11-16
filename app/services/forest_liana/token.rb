EXPIRATION_IN_DAYS = 2.days.to_i

module ForestLiana
  class TokenService

    def expiration_in_days()
      return EXPIRATION_IN_DAYS
    end

    def expiration_in_seconds()
      return EXPIRATION_IN_DAYS * 24 * 3600
    end

    def create_token(user, rendering_id)
      return JWT.encode({
        id: user[:id],
        email: user[:email],
        first_name: user[:first_name],
        last_name: user[:last_name],
        team: user[:teams][0],
        rendering_id: rendering_id,
        exp: Time.now.to_i + self.expiration_in_days()
      }, ForestLiana.auth_secret, 'HS256')
    end
  end
end
