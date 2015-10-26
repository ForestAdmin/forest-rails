module ForestLiana
  class StatsController < ForestLiana::ApplicationController
    before_filter :find_resource

    def show
      case stat_params[:type].try(:downcase)
      when 'value'
        stat = ValueStatGetter.new(@resource, stat_params)
      when 'pie'
        stat = PieStatGetter.new(@resource, stat_params)
      end

      stat.perform
      render json: serialize_model(stat.record)

      #if params[:aggregate].try(:downcase) == 'total'
        #render json: {
          #data: {
            #id: SecureRandom.uuid,
            #type: 'stats',
            #attributes: {
              #value: @resource.count
            #}
          #}
        #}
      #elsif params[:aggregate].try(:downcase) == 'count'
        #values = @resource.group(params[:field]).count.map do |key, value|
          #{
            #label: key,
            #value: value,
            #color: "#%06x" % (rand * 0xffffff),
            #highlight: "#%06x" % (rand * 0xffffff)
          #}
        #end

        #render json: {
          #data: {
            #id: SecureRandom.uuid,
            #type: 'stats',
            #attributes: {
              #value: values
            #}
          #}
        #}
      #else
        #render json: {status: 404}, status: :not_found
      #end
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_table_name(params[:collection])

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render json: {status: 404}, status: :not_found
      end
    end

    def stat_params
      params.require(:stat).permit(:type, :collection, :aggregate,
                                   :aggregate_field, :group_by_field)
    end

  end
end

