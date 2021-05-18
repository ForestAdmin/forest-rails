module ForestLiana
  class StripeSubscriptionSerializer
    include ForestAdmin::JSONAPI::Serializer

    attribute :cancel_at_period_end
    attribute :canceled_at
    attribute :created
    attribute :current_period_end
    attribute :current_period_start
    attribute :ended_at
    attribute :livemode
    attribute :quantity
    attribute :start
    attribute :status
    attribute :tax_percent
    attribute :trial_end
    attribute :trial_start

    has_one :customer

    def self_link
      "/forest#{super}"
    end

    def type
      @options[:context][:type] || 'stripe_subscriptions'
    end

    def format_name(attribute_name)
      attribute_name.to_s
    end

    def unformat_name(attribute_name)
      attribute_name.to_s
    end

    def relationship_self_link(attribute_name)
      nil
    end

    def relationship_related_link(attribute_name)
      nil
    end
  end
end
