module ForestLiana
  class StripeBankAccountSerializer
    include ForestAdmin::JSONAPI::Serializer

    attribute :account_holder_name
    attribute :account_holder_type
    attribute :bank_name
    attribute :country
    attribute :currency
    attribute :fingerprint
    attribute :last4
    attribute :routing_number
    attribute :status

    has_one :customer

    def self_link
      "/forest#{super}"
    end

    def type
      @options[:context][:type] || 'stripe_bank_accounts'
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
