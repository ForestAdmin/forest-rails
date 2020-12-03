EXPIRATION_IN_SECONDS = 14.days

module ForestLiana
  class Token
    REGEX_COOKIE_SESSION_TOKEN = /forest_session_token=([^;]*)/;

    def self.expiration_in_days
      Time.current + EXPIRATION_IN_SECONDS
    end

    def self.expiration_in_seconds
      return Time.now.to_i + EXPIRATION_IN_SECONDS
    end

    def self.create_token(user, rendering_id)
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
