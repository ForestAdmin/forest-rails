module ForestLiana
  class StripeInvoiceGetter < StripeBaseGetter
    attr_accessor :record

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def perform
      query = {}
      @record = ::Stripe::Invoice.retrieve(@params[:invoice_id])

      @record.date = Time.at(@record.date).to_datetime
      @record.period_start = Time.at(@record.period_start).to_datetime
      @record.period_end = Time.at(@record.period_end).to_datetime
      @record.subtotal /= 100.00
      @record.total /= 100.00
      @record.amount_due /= 100.00

      query[field] = @record.customer
      if collection
        @record.customer = collection.find_by(query)
      else
        @record.customer = nil
      end
      @record
    end
  end
end
