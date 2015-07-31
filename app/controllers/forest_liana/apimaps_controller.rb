require 'jsonapi-serializers'

module ForestLiana
  class ApimapsController < ForestLiana::ApplicationController
    def index
      result = []

      ActiveRecord::Base.connection.tables.map do |model_name|
        begin
          model = model_name.classify.constantize
          result << SchemaAdapter.new(model).perform
        rescue => error
          puts error.inspect
        end
      end

      render json: serialize_models(result, serializer: ApimapSerializer)
    end
  end
end
