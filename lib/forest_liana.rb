require 'forest_liana/engine'

module Forest
end

module ForestLiana

  autoload :MixpanelEvent, 'forest_liana/mixpanel_event'

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
  mattr_accessor :names_overriden
  # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
  mattr_accessor :names_old_overriden

  self.apimap = []
  self.allowed_users = []
  self.models = []
  self.excluded_models = []
  self.included_models = []
  self.user_class_name = nil
  self.names_overriden = {}

  # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
  self.names_old_overriden = {}

  def self.schema_for_resource resource
    self.apimap.find do |collection|
      SchemaUtils.find_model_from_collection_name(collection.name)
        .try(:name) == resource.name
    end
  end

  def self.name_for(model)
    self.names_overriden[model] || model.try(:name).gsub('::', '__')
  end

  # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
  def self.name_old_for(model)
    self.names_old_overriden[model] || model.try(:table_name)
  end

  def self.component_prefix(model)
    self.name_for(model).classify
  end
end
