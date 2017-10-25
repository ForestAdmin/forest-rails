module ForestLiana
  class IntercomConversationSerializer
    include JSONAPI::Serializer

    attribute :created_at
    attribute :updated_at
    attribute :open
    attribute :read

    attribute :subject do
      object.conversation_message.subject
    end

    attribute :body do
      object.conversation_message.body
    end

    attribute :assignee do
      object.assignee.try(:email)
    end

    def self_link
      "/forest#{super}"
    end

    def type
      @options[:context][:type] || 'intercom-conversations'
    end

    def format_name(attribute_name)
      attribute_name.to_s
    end

    def unformat_name(attribute_name)
      attribute_name.to_s.underscore
    end

    def relationship_self_link(attribute_name)
      nil
    end

    def relationship_related_link(attribute_name)
      nil
    end
  end
end
