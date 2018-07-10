module ForestLiana
  class StripeSourceGetter < StripeBaseGetter
    attr_accessor :record

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def perform
      resource = collection.find(@params[:recordId])
      customer = resource[field]

      @record = ::Stripe::Customer
        .retrieve(customer)
        .sources.retrieve(@params[:objectId])

      query = {}
      query[field] = @record.customer
      @record.customer = collection.find_by(query)

      @record
    end
  end
end
