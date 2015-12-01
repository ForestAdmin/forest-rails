module ForestLiana
  class StripeInvoicesGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      @reference_model, @reference_field = reference_model(reference)
      Stripe.api_key = secret_key
    end

    def count
      @invoices.try(:total_count) || 0
    end

    def perform
      query = { limit: limit, offset: offset }

      if reference_model_id
        resource = @reference_model.find(reference_model_id)
        query[:customer] = resource[@reference_field]
      end

      query['include[]'] = 'total_count'
      @invoices = fetch_invoices(query)
      if @invoices.blank?
        @records = []
        return
      end

      @records = @invoices.data.map do |d|
        d.date = Time.at(d.date).to_datetime
        d.period_start = Time.at(d.period_start).to_datetime
        d.period_end = Time.at(d.period_end).to_datetime
        d.subtotal /= 100.00
        d.total /= 100.00
        d.amount_due /= 100.00

        query = {}
        query[@reference_field] = d.customer
        if @reference_model
          d.customer = @reference_model.find_by(query)
        else
          d.customer = nil
        end

        d
      end
    end

    def fetch_invoices(params)
      return if reference_model_id && params[:customer].blank?
      Stripe::Invoice.all(params)
    end

    def reference_model(reference)
      resource_name, reference_field = reference.split('.')
      reference_model = SchemaUtils.find_model_from_table_name(resource_name)

      [reference_model, reference_field]
    end

    def reference_model_id
      if @reference_model
        @params["#{@reference_model.table_name.singularize()}Id"]
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

  end
end

