require 'jsonapi-serializers'

module ForestLiana
  class ApimapSerializer
    include JSONAPI::Serializer

    attribute :name
    attribute :fields
  end
end
