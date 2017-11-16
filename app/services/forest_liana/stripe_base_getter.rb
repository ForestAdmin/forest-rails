module ForestLiana
  class StripeBaseGetter < IntegrationBaseGetter
    private

    def field
      ForestLiana.integrations[:stripe][:mapping].select { |value|
        value.split('.')[0] == ForestLiana::SchemaUtils
          .find_model_from_collection_name(@params[:collection]).try(:name)
      }.first.split('.')[1]
    end
  end
end
