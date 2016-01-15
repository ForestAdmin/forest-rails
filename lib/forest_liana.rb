require 'forest_liana/engine'

module ForestLiana
  module UserSpace
  end

  mattr_accessor :jwt_signing_key
  mattr_accessor :integrations
  mattr_accessor :apimap
  self.apimap = []
end
