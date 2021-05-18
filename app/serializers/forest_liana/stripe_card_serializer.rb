module ForestLiana
  class StripeCardSerializer
    include ForestAdmin::JSONAPI::Serializer

    attribute :last4
    attribute :brand
    attribute :funding
    attribute :exp_month
    attribute :exp_year
    attribute :country
    attribute :name
    attribute :address_line1
    attribute :address_line2
    attribute :address_city
    attribute :address_state
    attribute :address_zip
    attribute :address_country
    attribute :cvc_check

    has_one :customer

    def self_link
      "/forest#{super}"
    end

    def type
      @options[:context][:type] || 'stripe_cards'
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
