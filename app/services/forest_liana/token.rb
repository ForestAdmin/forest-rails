EXPIRATION_IN_DAYS = Time.current + 14.days

module ForestLiana
  class Token

    def expiration_in_days()
      return EXPIRATION_IN_DAYS
    end

    def expiration_in_seconds()
      return EXPIRATION_IN_DAYS.to_i * 24 * 3600
    end

    def create_token(user, rendering_id)
      return JWT.encode({
        id: user['id'],
        email: user['email'],
        first_name: user['first_name'],
        last_name: user['last_name'],
        team: user['teams'][0],
        rendering_id: rendering_id,
        exp: expiration_in_seconds()
      }, ForestLiana.auth_secret, 'HS256')
    end
  end
end
