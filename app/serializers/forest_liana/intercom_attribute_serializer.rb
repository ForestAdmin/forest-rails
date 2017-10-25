module ForestLiana
  class IntercomAttributeSerializer
    include JSONAPI::Serializer

    attribute :session_count
    attribute :last_seen_ip

    attribute :created_at do
      object.created_at.try(:utc).try(:iso8601)
    end

    attribute :updated_at do
      object.updated_at.try(:utc).try(:iso8601)
    end

    attribute :signed_up_at do
      object.signed_up_at.try(:utc).try(:iso8601)
    end

    attribute :last_request_at do
      object.last_request_at.try(:utc).try(:iso8601)
    end

    attribute :country do
      object.location_data.try(:country_name)
    end

    attribute :city do
      object.location_data.try(:city_name)
    end

    attribute :user_agent do
      object.user_agent_data
    end

    attribute :companies do
      object.companies.map(&:name)
    end

    attribute :segments do
      object.segments.map(&:name)
    end

    attribute :tags do
      object.tags.map(&:name)
    end

    attribute :browser do
      useragent = UserAgent.parse(object.user_agent_data)
      "#{useragent.try(:browser)} #{useragent.try(:version)}"
    end

    attribute :platform do
      UserAgent.parse(object.user_agent_data).try(:platform)
    end

    attribute :geoloc do
      [object.location_data.try(:latitude), object.location_data.try(:longitude)]
    end

    def self_link
      "/forest#{super}"
    end

    def type
      @options[:context][:type] || 'intercom-attributes'
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
