class ForestLiana::Model::Action
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Serialization
  extend ActiveModel::Naming

  # TODO: Remove :global option when we remove the deprecation warning.
  attr_accessor :id, :name, :endpoint, :http_method, :fields, :redirect,
    :global, :type, :download

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def persisted?
    false
  end
end
