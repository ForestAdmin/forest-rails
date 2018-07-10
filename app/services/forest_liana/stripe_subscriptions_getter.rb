module ForestLiana
  class StripeSubscriptionsGetter < StripeBaseGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def count
      @subscriptions.try(:total_count) || 0
    end

    def perform
      begin
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
      rescue ::Stripe::InvalidRequestError => error
        FOREST_LOGGER.error "Stripe error: #{error.message}"
        @records = []
      end
    end

    def fetch_subscriptions(params)
      return if @params[:id] && params[:customer].blank?
      ::Stripe::Subscription.all(params)
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
  end
end
