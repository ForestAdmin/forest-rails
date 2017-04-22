require 'forest_liana/engine'

module Forest
end

module ForestLiana
  module UserSpace
  end

  # NOTICE: Deprecated secret value names
  mattr_accessor :secret_key
  mattr_accessor :auth_key

  mattr_accessor :env_secret
  mattr_accessor :auth_secret
  mattr_accessor :integrations
  mattr_accessor :apimap
  mattr_accessor :allowed_users
  mattr_accessor :models
  mattr_accessor :excluded_models
  mattr_accessor :included_models
  mattr_accessor :user_class_name

  self.apimap = []
  self.allowed_users = []
  self.models = []
  self.excluded_models = []
  self.included_models = []
  self.user_class_name = nil

  def self.schema_for_resource resource
    self.apimap.find {|collection| collection.name == resource.table_name}
  end
end
