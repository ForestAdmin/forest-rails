module ForestLiana
  class StripePaymentSerializer
    include JSONAPI::Serializer

    attribute :description
    attribute :customer
    attribute :refunded
    attribute :currency
    attribute :status
    attribute :amount
    attribute :created

    def self_link
      "/forest#{super}"
    end

    def type
      'stripe-payments'
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
  end
end
