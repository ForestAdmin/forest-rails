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
      params = { limit: limit, offset: offset, object: 'card' }
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

    def offset
      return 0 unless pagination?

      number = @params[:page][:number]
      if number && number.to_i > 0
        (number.to_i - 1) * limit
      else
        0
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
      @params[:page] && @params[:page][:number]
    end

    def collection
      @params[:collection].singularize.capitalize.constantize
    end

    def field
      ForestLiana.integrations[:stripe][:mapping].select { |value|
        value.split('.')[0] == @params[:collection].singularize.capitalize
      }.first.split('.')[1]
    end
  end
end
