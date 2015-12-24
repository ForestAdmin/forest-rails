class ForestLiana::Model::Collection
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Serialization
  extend ActiveModel::Naming

  attr_accessor :name, :fields, :actions

  def initialize(attributes = {})
    @actions = []

    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def persisted?
    false
  end

  def id
    name
  end
end
