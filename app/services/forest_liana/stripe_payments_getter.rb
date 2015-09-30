module ForestLiana
  class StripePaymentsGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      @reference_model, @reference_field = reference_model(reference)
      Stripe.api_key = secret_key
    end

    def has_more
      @charges.has_more
    end

    def perform
      params = { limit: 10 }
      params[:starting_after] = @params[:page][:lastItemId] \
        if @params[:page][:lastItemId]

      params[:ending_before] = @params[:page][:firstItemId] \
        if @params[:page][:firstItemId]

      @charges = Stripe::Charge.all(params)

      @records = @charges.data.map do |d|
        d.created = Time.at(d.created).to_datetime
        d.amount /= 100

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
  end
end
