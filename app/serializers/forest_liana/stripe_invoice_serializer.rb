module ForestLiana
  class StripeInvoiceSerializer
    include ForestAdmin::JSONAPI::Serializer

    attribute :amount_due
    attribute :amount_paid
    attribute :amount_remaining
    attribute :application_fee_amount
    attribute :attempt_count
    attribute :attempted
    attribute :currency
    attribute :due_date
    attribute :paid
    attribute :period_end
    attribute :period_start
    attribute :status
    attribute :subtotal
    attribute :total
    attribute :tax

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
