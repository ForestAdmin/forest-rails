require 'jsonapi-serializers'

class ForestLiana::SegmentSerializer
  include JSONAPI::Serializer

  attribute :name

  def relationship_related_link(attribute_name)
    nil
  end

  def relationship_self_link(attribute_name)
    nil
  end
end
