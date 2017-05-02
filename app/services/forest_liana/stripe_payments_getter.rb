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
      query = {
        limit: limit,
        starting_after: starting_after,
        ending_before: ending_before
      }

      if @params[:id] && collection && field
        resource = collection.find(@params[:id])
        query[:customer] = resource[field]
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
        query[field] = d.customer
        if collection
          d.customer = collection.find_by(query)
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
          .find_model_from_collection_name(@params[:collection]).try(:name)
      }.first.split('.')[1]
    end
  end
end
