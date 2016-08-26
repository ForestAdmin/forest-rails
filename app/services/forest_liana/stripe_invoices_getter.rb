module ForestLiana
  class StripeInvoicesGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def count
      @invoices.try(:total_count) || 0
    end

    def perform
      query = { limit: limit, offset: offset }

      if @params[:id] && collection && field
        resource = collection.find(@params[:id])
        query[:customer] = resource[field]
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
        query[field] = d.customer
        if collection
          d.customer = collection.find_by(query)
        else
          d.customer = nil
        end

        d
      end
    end

    def fetch_invoices(params)
      return if @params[:id] && params[:customer].blank?
      Stripe::Invoice.all(params)
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

