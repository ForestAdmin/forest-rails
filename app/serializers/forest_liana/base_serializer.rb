require 'jsonapi-serializers'

class ForestLiana::BaseSerializer
  include JSONAPI::Serializer

  def format_name(attribute_name)
    return attribute_name.to_s.underscore
  end
end
