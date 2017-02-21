module ForestLiana
  class StripeCardsGetter
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
        object: 'card'
      }
      params['include[]'] = 'total_count'

      resource = collection.find(@params[:id])
      customer = resource[field]

      if customer.blank?
        @records = []
      else
        fetch_cards(customer, params)
      end
    end

    def fetch_cards(customer, params)
      @cards = Stripe::Customer.retrieve(customer).sources.all(params)
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
          .find_model_from_table_name(@params[:collection]).try(:name)
      }.first.split('.')[1]
    end
  end
end
