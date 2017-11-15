module ForestLiana
  class StripeSourceGetter
    attr_accessor :record

    def initialize(params, secret_key, reference)
      @params = params
      Stripe.api_key = ForestLiana.integrations[:stripe][:api_key]
    end

    def perform
      resource = collection.find(@params[:recordId])
      customer = resource[field]

      @record = Stripe::Customer
        .retrieve(customer)
        .sources.retrieve(@params[:objectId])

      query = {}
      query[field] = @record.customer
      @record.customer = collection.find_by(query)

      @record
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
