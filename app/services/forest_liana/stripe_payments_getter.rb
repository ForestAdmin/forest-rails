module ForestLiana
  class StripePaymentsGetter
    attr_accessor :records

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def count
      @charges.try(:total_count) || 0
    end

    def perform
      query = { limit: limit, offset: offset }

      if @params[:id] && user_collection && user_field
        resource = user_collection.find(@params[:id])
        query[:customer] = resource[user_field]
      end

      query['source'] = { object: :card }
      query['include[]'] = 'total_count'

      @charges = fetch_charges(query)
      if @charges.blank?
        @records = []
        return
      end

      @records = @charges.data.map do |d|
        d.created = Time.at(d.created).to_datetime
        d.amount /= 100.00

        query = {}
        query[user_field] = d.customer
        if user_collection
          d.customer = user_collection.find_by(query)
        else
          d.customer = nil
        end

        d
      end
    end

    def fetch_charges(params)
      return if @params[:id] && params[:customer].blank?
      Stripe::Charge.all(params)
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

    def user_collection
      ForestLiana.integrations
        .try(:[], :stripe)
        .try(:[], :user_collection)
        .try(:constantize)
    end

    def user_field
      ForestLiana.integrations
        .try(:[], :stripe)
        .try(:[], :user_field)
    end
  end
end
