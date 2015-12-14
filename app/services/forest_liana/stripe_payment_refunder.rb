module ForestLiana
  class StripePaymentRefunder
    def initialize(params)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
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
