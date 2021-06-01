module ForestLiana
  class MixpanelEventSerializer
    include JSONAPI::Serializer

    attribute :id
    attribute :event
    attribute :city
    attribute :region
    attribute :timezone
    attribute :os
    attribute :osVersion
    attribute :country
    attribute :date
    attribute :browser

    def self_link
      nil
    end

    def type
      @options[:context][:type] || 'mixpanel_events'
    end
  end
end
