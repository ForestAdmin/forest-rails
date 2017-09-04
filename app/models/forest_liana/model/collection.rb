class ForestLiana::Model::Collection
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include ActiveModel::Serialization
  extend ActiveModel::Naming

  attr_accessor :name, :fields, :actions, :segments, :only_for_relationships,
    :is_virtual, :is_read_only, :is_searchable, :display_name, :icon,
    :integration, :pagination_type, :search_fields

  def initialize(attributes = {})
    @actions = []
    @segments = []
    @is_searchable = true
    @is_read_only = false
    @search_fields = nil

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
