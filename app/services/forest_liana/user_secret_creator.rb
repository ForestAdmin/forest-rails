require 'base32'

module ForestLiana
  # NOTICE: This service combines the 2FA secret stored on the forest server to the local secret
  #         salt. This guarantees that only the owner of the server and the concerned end user can
  #         know the final key.
  #         This is done by using a bitwise exclusive or operation, which guarantees the key to stay
  #         unique, so it is impossible for two users to have the same key.
  class UserSecretCreator
    def initialize(two_factor_authentication_secret, two_factor_secret_salt)
      @two_factor_authentication_secret = two_factor_authentication_secret
      @two_factor_secret_salt = two_factor_secret_salt
    end

    def perform
      hash = (@two_factor_authentication_secret.to_i(16) ^ @two_factor_secret_salt.to_i(16)).to_s(16)
      bin_hash = hex_to_bin(hash)

      Base32.encode(bin_hash).tr('=', '')
    end

    def hex_to_bin(hex_string)
      hex_string.scan(/../).map { |x| x.hex.chr }.join
    end
  end
end
