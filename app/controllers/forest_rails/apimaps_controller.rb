module ForestRails
  class ApimapsController < ForestRails::ApplicationController
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

      render json: result, each_serializer: ApimapSerializer
    end
  end
end
