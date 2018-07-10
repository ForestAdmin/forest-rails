module ForestLiana
  class StripeSubscriptionGetter < StripeBaseGetter
    attr_accessor :record

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def perform
      query = {}
      @record = ::Stripe::Subscription.retrieve(@params[:subscription_id])

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
