module ForestLiana
  class StripeController < ForestLiana::ApplicationController

    def payments
      getter = StripePaymentsGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_payments') },
        count: getter.count,
        include: ['customer']
      })
    end

    def payment
      getter = StripePaymentGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_model(getter.record, {
        context: { type: get_serializer_type('stripe_payments') },
        skip_collection_check: true,
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
      params[:object] = 'card'
      getter = StripeSourcesGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_cards') },
        count: getter.count,
        include: ['customer']
      })
    end

    def card
      getter = StripeSourceGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_model(getter.record, {
        context: { type: get_serializer_type('stripe_cards') },
        skip_collection_check: true,
        include: ['customer']
      })
    end

    def invoices
      getter = StripeInvoicesGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_invoices') },
        count: getter.count,
        include: ['customer']
      })
    end

    def invoice
      getter = StripeInvoiceGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_model(getter.record, {
        context: { type: get_serializer_type('stripe_invoices') },
        skip_collection_check: true,
        include: ['customer']
      })
    end

    def subscriptions
      getter = StripeSubscriptionsGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_subscriptions') },
        count: getter.count,
        include: ['customer']
      })
    end

    def subscription
      getter = StripeSubscriptionGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_model(getter.record, {
        context: { type: get_serializer_type('stripe_subscriptions') },
        skip_collection_check: true,
        include: ['customer']
      })
    end

    def bank_accounts
      params[:object] = 'bank_account'
      getter = StripeSourcesGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_bank_accounts') },
        count: getter.count,
        include: ['customer']
      })
    end

    def bank_account
      getter = StripeSourceGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_model(getter.record, {
        context: { type: get_serializer_type('stripe_bank_accounts') },
        skip_collection_check: true,
        include: ['customer']
      })
    end

    def get_serializer_type(suffix)
      "#{params[:collection]}_#{suffix}"
    end
  end
end
