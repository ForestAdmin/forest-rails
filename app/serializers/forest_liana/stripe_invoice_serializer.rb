module ForestLiana
  class StripeInvoiceSerializer
    include JSONAPI::Serializer

    attribute :amount_due
    attribute :attempt_count
    attribute :attempted
    attribute :closed
    attribute :currency
    attribute :date
    attribute :forgiven
    attribute :paid
    attribute :period_end
    attribute :period_start
    attribute :subtotal
    attribute :total
    attribute :application_fee
    attribute :tax
    attribute :tax_percent

    has_one :customer

    def self_link
      "/forest#{super}"
    end

    def type
      @options[:context][:type] || 'stripe_invoices'
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
