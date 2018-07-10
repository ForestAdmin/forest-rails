module ForestLiana
  class StripePaymentGetter < StripeBaseGetter
    attr_accessor :record

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def perform
      query = {}
      @record = ::Stripe::Charge.retrieve(@params[:payment_id])

      @record.created = Time.at(@record.created).to_datetime
      @record.amount /= 100.00

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
