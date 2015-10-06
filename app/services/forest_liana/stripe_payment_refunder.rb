module ForestLiana
  class StripePaymentRefunder
    def initialize(params)
      @params = params
      Stripe.api_key = params[:parameters][:stripeSecretKey]
    end

    def perform
      return unless @params[:jsonapis]

      @params[:jsonapis].each do |jsonapi|
        ch = Stripe::Charge.retrieve(jsonapi[:data][:id])
        ch.refunds.create
      end
    end
  end
end
