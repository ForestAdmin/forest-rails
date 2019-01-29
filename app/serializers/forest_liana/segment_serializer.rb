require 'jsonapi-serializers'

class ForestLiana::SegmentSerializer < ForestLiana::BaseSerializer
  attribute :name

  def relationship_related_link(attribute_name)
    nil
  end

  def relationship_self_link(attribute_name)
    nil
  end
end
