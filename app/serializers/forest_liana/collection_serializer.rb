require 'jsonapi-serializers'

class ForestLiana::CollectionSerializer
  include JSONAPI::Serializer

  attribute :name
  attribute :name_old # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
  attribute :display_name
  attribute :icon
  attribute :integration
  attribute :fields
  attribute :only_for_relationships
  attribute :is_virtual
  attribute :is_read_only
  attribute :is_searchable
  attribute :pagination_type

  has_many :actions do
    object.actions
  end

  has_many :segments do
    object.segments
  end

  def relationship_related_link(attribute_name)
    nil
  end

  def relationship_self_link(attribute_name)
    nil
  end
end
