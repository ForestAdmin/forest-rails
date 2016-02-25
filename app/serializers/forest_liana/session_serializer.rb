module ForestLiana
  class SessionSerializer
    include JSONAPI::Serializer

    attribute :first_name
    attribute :last_name
    attribute :email

    def type
      'users'
    end

    def format_name(attribute_name)
      attribute_name.to_s
    end

    def unformat_name(attribute_name)
      attribute_name.to_s.underscore
    end

    def self_link
      nil
    end

    def relationship_self_link(attribute_name)
      nil
    end

    def relationship_related_link(attribute_name)
      nil
    end
  end
end
