module ForestLiana
  class StripeSubscriptionsGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def count
      @subscriptions.try(:total_count) || 0
    end

    def perform
      query = {
        limit: limit,
        starting_after: starting_after,
        ending_before: ending_before
      }

      if @params[:id] && collection && field
        resource = collection.find(@params[:id])
        query[:customer] = resource[field]
      end

      query['include[]'] = 'total_count'
      @subscriptions = fetch_subscriptions(query)
      if @subscriptions.blank?
        @records = []
        return
      end

      @records = @subscriptions.data.map do |d|
        query = {}
        query[field] = d.customer
        if collection
          d.customer = collection.find_by(query)
        else
          d.customer = nil
        end

        d
      end
    end

    def fetch_subscriptions(params)
      return if @params[:id] && params[:customer].blank?
      Stripe::Subscription.all(params)
    end

    def starting_after
      if pagination? && @params[:starting_after]
        @params[:starting_after]
      end
    end

    def ending_before
      if pagination? && @params[:ending_before]
        @params[:ending_before]
      end
    end

    def limit
      return 10 unless pagination?

      if @params[:page][:size]
        @params[:page][:size].to_i
      else
        10
      end
    end

    def pagination?
      @params[:page]
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
