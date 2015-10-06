module ForestLiana
  class StripePaymentsGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      @reference_model, @reference_field = reference_model(reference)
      Stripe.api_key = secret_key
    end

    def count
      @charges.try(:total_count) || 0
    end

    def perform
      query = { limit: limit, offset: offset }

      if reference_model_id
        resource = @reference_model.find(reference_model_id)
        query[:customer] = resource[@reference_field]
      end

      query['source'] = { object: :card }
      query['include[]'] = 'total_count'

      @charges = fetch_charges(query)

      @records = @charges.data.map do |d|
        d.created = Time.at(d.created).to_datetime
        d.amount /= 100

        query = {}
        query[@reference_field] = d.customer
        d.customer = @reference_model.find_by(query)

        d
      end
    end

    def fetch_charges(params)
      return if reference_model_id && params[:customer].blank?
      Stripe::Charge.all(params)
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
