module ForestLiana
  class StripeInvoiceGetter
    attr_accessor :record

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def perform
      query = {}
      @record = Stripe::Invoice.retrieve(@params[:invoice_id])

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

    def collection
      @params[:collection].singularize.camelize.constantize
    end

    def field
      ForestLiana.integrations[:stripe][:mapping].select { |value|
        value.split('.')[0] == ForestLiana::SchemaUtils
          .find_model_from_collection_name(@params[:collection]).try(:name)
      }.first.split('.')[1]
    end
  end
end
