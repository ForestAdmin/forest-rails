module ForestLiana
  class StripePaymentRefunder
    def initialize(params)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def perform
      return unless @params[:data][:attributes][:ids]

      @params[:data][:attributes][:ids].each do |id|
        ch = ::Stripe::Charge.retrieve(id)
        ch.refunds.create
      end
    end
  end
end
