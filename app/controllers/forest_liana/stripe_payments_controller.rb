module ForestLiana
  class StripePaymentsController < ForestLiana::ApplicationController

    def index
      getter = StripePaymentsGetter.new(request.headers['Stripe-Secret-Key'])
      getter.perform

      render json: serialize_models(getter.records)
    end
  end
end
