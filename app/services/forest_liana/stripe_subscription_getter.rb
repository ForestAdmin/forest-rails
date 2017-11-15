module ForestLiana
  class StripeSubscriptionGetter
    attr_accessor :record

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def perform
      query = {}
      @record = Stripe::Subscription.retrieve(@params[:subscription_id])

      @record.canceled_at = Time.at(@record.canceled_at).to_datetime
      @record.created = Time.at(@record.created).to_datetime
      @record.current_period_end = Time.at(@record.current_period_end).to_datetime
      @record.current_period_start = Time.at(@record.current_period_start).to_datetime
      @record.ended_at = Time.at(@record.ended_at).to_datetime
      @record.start = Time.at(@record.start).to_datetime
      @record.trial_end = Time.at(@record.trial_end).to_datetime
      @record.trial_start = Time.at(@record.trial_start).to_datetime

      query[field] = @record.customer
      if collection
        @record.customer = collection.find_by(query)
      else
        @record.customer = nil
      end
      @record
    end

    def collection
      @params[:collection].singularize.camelize.constantize
    end

    def field
      ForestLiana.integrations[:stripe][:mapping].select { |value|
        value.split('.')[0] == ForestLiana::SchemaUtils
          .find_model_from_collection_name(@params[:collection]).try(:name)
      }.first.split('.')[1]
    end
  end
end
