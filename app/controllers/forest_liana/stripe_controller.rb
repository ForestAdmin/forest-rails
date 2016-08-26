module ForestLiana
  class StripeController < ForestLiana::ApplicationController

    def payments
      getter = StripePaymentsGetter.new(params,
                                        request.headers['Stripe-Secret-Key'],
                                        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_payments') },
        count: getter.count,
        include: ['customer']
      })
    end

    def refund
      begin
        refunder = StripePaymentRefunder.new(params)
        refunder.perform

        render serializer: nil, json: {}
      rescue Stripe::InvalidRequestError => err
        render serializer: nil, json: { error: err.message }, status: 400
      end
    end

    def cards
      getter = StripeCardsGetter.new(params,
                                     request.headers['Stripe-Secret-Key'],
                                     request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_cards') },
        count: getter.count,
        include: ['customer']
      })
    end

    def invoices
      getter = StripeInvoicesGetter.new(params,
                                        request.headers['Stripe-Secret-Key'],
                                        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_invoices') },
        count: getter.count,
        include: ['customer']
      })
    end

    def get_serializer_type(suffix)
      "#{params[:collection].singularize}_#{suffix}"
    end
  end
end
