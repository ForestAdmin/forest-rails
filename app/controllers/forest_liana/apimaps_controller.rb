require 'jsonapi-serializers'

module ForestLiana
  class ApimapsController < ForestLiana::ApplicationController
    def index
      result = []

      SchemaUtils.tables_names.map do |table_name|
        model = SchemaUtils.find_model_from_table_name(table_name)
        result << SchemaAdapter.new(model).perform if model.try(:table_exists?)
      end

      render json: serialize_models(result, serializer: ApimapSerializer)
    end
  end
end
