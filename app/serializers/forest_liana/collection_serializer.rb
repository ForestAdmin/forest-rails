require 'jsonapi-serializers'

class ForestLiana::CollectionSerializer < ForestLiana::BaseSerializer
  attribute :name
  attribute :name_old # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
  attribute :icon
  attribute :integration
  attribute :fields
  attribute :only_for_relationships
  attribute :is_virtual
  attribute :is_read_only
  attribute :is_searchable
  attribute :pagination_type

  has_many :actions
  has_many :segments

  def relationship_related_link(attribute_name)
    nil
  end

  def relationship_self_link(attribute_name)
    nil
  end
end
