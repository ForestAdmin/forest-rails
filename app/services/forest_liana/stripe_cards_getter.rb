module ForestLiana
  class StripeCardsGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      @reference_model, @reference_field = reference_model(reference)
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def count
      @cards.try(:total_count) || 0
    end

    def perform
      params = { limit: limit, offset: offset, object: 'card' }
      params['include[]'] = 'total_count'

      resource = @reference_model.find(reference_model_id)
      customer = resource[@reference_field]

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
        query[@reference_field] = d.customer
        d.customer = @reference_model.find_by(query)

        d
      end
    end

    def reference_model(reference)
      resource_name, reference_field = reference.split('.')
      reference_model = SchemaUtils.find_model_from_table_name(resource_name)

      [reference_model, reference_field]
    end

    def reference_model_id
      @params["#{@reference_model.table_name.singularize()}Id"]
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
  end
end
