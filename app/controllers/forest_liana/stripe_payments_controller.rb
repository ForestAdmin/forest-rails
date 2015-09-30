module ForestLiana
  class StripePaymentsController < ForestLiana::ApplicationController

    def index
      getter = StripePaymentsGetter.new(params,
                                        request.headers['Stripe-Secret-Key'],
                                        request.headers['Stripe-Reference'])
      getter.perform

      render json: serialize_models(getter.records, {
        has_more: getter.has_more,
        include: ['customer']
      })
    end
  end
end
