module ForestLiana
  class StatsController < ForestLiana::ApplicationController
    before_filter :find_resource

    def show
      case stat_params[:type].try(:downcase)
      when 'value'
        stat = ValueStatGetter.new(@resource, stat_params)
      when 'pie'
        stat = PieStatGetter.new(@resource, stat_params)
      when 'line'
        stat = LineStatGetter.new(@resource, stat_params)
      end

      stat.perform
      if stat.record
        render json: serialize_model(stat.record)
      else
        render json: {status: 404}, status: :not_found
      end
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_table_name(params[:collection])

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render json: {status: 404}, status: :not_found
      end
    end

    def stat_params
      # Avoid to warn/crash if there's no filters.
      params[:stat].delete(:filters) if params[:stat][:filters].blank?

      params.require(:stat).permit(:type, :collection, :aggregate, :time_range,
                                   :aggregate_field, :group_by_field,
                                   :group_by_date_field, :filters => [
                                     :field, :value
                                   ])
    end

  end
end

