module ForestLiana
  class StripeController < ForestLiana::ApplicationController

    def payments
      getter = StripePaymentsGetter.new(params,
                                        request.headers['Stripe-Secret-Key'],
                                        request.headers['Stripe-Reference'])
      getter.perform

      render json: serialize_models(getter.records, {
        count: getter.count,
        include: ['customer']
      })
    end

    def cards
      getter = StripeCardsGetter.new(params,
                                     request.headers['Stripe-Secret-Key'],
                                     request.headers['Stripe-Reference'])
      getter.perform

      render json: serialize_models(getter.records, {
        count: getter.count,
        include: ['customer']
      })
    end
  end
end
