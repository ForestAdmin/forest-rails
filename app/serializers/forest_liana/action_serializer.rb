require 'jsonapi-serializers'

class ForestLiana::ActionSerializer
  include JSONAPI::Serializer

  attribute :name
  attribute :http_method
  attribute :endpoint
  attribute :fields
  attribute :redirect

  def relationship_related_link(attribute_name)
    nil
  end

  def relationship_self_link(attribute_name)
    nil
  end
end
