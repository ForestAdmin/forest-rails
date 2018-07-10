module ForestLiana
  class StripeSourcesGetter < StripeBaseGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def count
      @cards.try(:total_count) || 0
    end

    def perform
      params = {
        limit: limit,
        starting_after: starting_after,
        ending_before: ending_before,
        object: @params[:object]
      }
      params['include[]'] = 'total_count'

      resource = collection.find(@params[:id])
      customer = resource[field]

      if customer.blank?
        @records = []
      else
        fetch_bank_accounts(customer, params)
      end
    end

    def fetch_bank_accounts(customer, params)
      begin
        @cards = ::Stripe::Customer.retrieve(customer).sources.all(params)
        if @cards.blank?
          @records = []
          return
        end

        @records = @cards.data.map do |d|
          query = {}
          query[field] = d.customer
          d.customer = collection.find_by(query)

          d
        end
      rescue ::Stripe::InvalidRequestError => error
        FOREST_LOGGER.error "Stripe error: #{error.message}"
        @records = []
      end
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
