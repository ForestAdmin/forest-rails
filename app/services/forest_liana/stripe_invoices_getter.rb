module ForestLiana
  class StripeInvoicesGetter < StripeBaseGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def count
      @invoices.try(:total_count) || 0
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
      rescue ::Stripe::InvalidRequestError => error
        FOREST_LOGGER.error "Stripe error: #{error.message}"
        @records = []
      end
    end

    def fetch_invoices(params)
      return if @params[:id] && params[:customer].blank?
      ::Stripe::Invoice.all(params)
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
