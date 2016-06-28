module ForestLiana
  class StatsController < ForestLiana::ApplicationController
    before_filter :find_resource

    def show
      case params[:type].try(:downcase)
      when 'value'
        stat = ValueStatGetter.new(@resource, params)
      when 'pie'
        stat = PieStatGetter.new(@resource, params)
      when 'line'
        stat = LineStatGetter.new(@resource, params)
      end

      stat.perform
      if stat.record
        render json: serialize_model(stat.record), serializer: nil
      else
        render json: {status: 404}, status: :not_found, serializer: nil
      end
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_table_name(params[:collection])

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render json: {status: 404}, status: :not_found, serializer: nil
      end
    end
  end
end

