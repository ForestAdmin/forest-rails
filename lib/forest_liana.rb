require 'forest_liana/engine'

module Forest
end

module ForestLiana
  module UserSpace
  end

  mattr_accessor :secret_key
  mattr_accessor :auth_key
  mattr_accessor :integrations
  mattr_accessor :apimap
  mattr_accessor :allowed_users
  mattr_accessor :models

  # Legacy.
  mattr_accessor :jwt_signing_key

  self.apimap = []
  self.allowed_users = []
  self.models = []
end
