module ForestLiana
  class StripeController < ForestLiana::ApplicationController
    include ForestLiana::Ability

    rescue_from ForestLiana::Ability::Exceptions::TriggerForbidden, with: :render_error
    rescue_from ForestLiana::Ability::Exceptions::RequireApproval, with: :render_error
    rescue_from ForestLiana::Ability::Exceptions::UnsupportedConditionals, with: :render_error

    before_action :authorize_refund, only: :refund

    def payments
      getter = StripePaymentsGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_payments') },
        meta: { count: getter.count },
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
        refunder = StripePaymentRefunder.new(@refund_parameters)
        refunder.perform

        render serializer: nil, json: {}
      rescue ::Stripe::InvalidRequestError => error
        render serializer: nil, json: { error: error.message }, status: 400
      end
    end

    def cards
      params[:object] = 'card'
      getter = StripeSourcesGetter.new(params, request.headers['Stripe-Secret-Key'],
        request.headers['Stripe-Reference'])
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('stripe_cards') },
        meta: { count: getter.count },
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
        meta: { count: getter.count },
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
        meta: { count: getter.count },
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
        meta: { count: getter.count },
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

    private

    def authorize_refund
      raise ForestLiana::Errors::HTTP422Error.new if params.dig(:data, :attributes, :requester_id).present?

      parameters = refund_request_parameters
      collection_name = parameters.dig(:data, :attributes, :collection_name).to_s
      is_integration_action_authorized?(forest_user, collection_name, 'Refund', params)
      @refund_parameters = parameters
    end

    def refund_request_parameters
      return params.permit! unless params.dig(:data, :attributes, :signed_approval_request)

      ForestLiana::Ability::Permission::RequestPermission.decodeSignedApprovalRequest(params.permit!)
    rescue JWT::DecodeError
      raise ForestLiana::Errors::HTTP400Error.new('Invalid signed action parameters')
    end
  end
end
