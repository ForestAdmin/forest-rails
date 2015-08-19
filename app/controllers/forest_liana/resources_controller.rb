module ForestLiana
  class ResourcesController < ForestLiana::ApplicationController

    before_filter :find_resource

    def index
      getter = ResourcesGetter.new(@resource, params)
      getter.perform

      render json: serialize_models(getter.records,
                                    include: includes,
                                    count: getter.count,
                                    params: params)
    end

    def show
      getter = ResourceGetter.new(@resource, params)
      getter.perform

      render json: serialize_model(getter.record, include: includes)
    end

    def create
      if Rails::VERSION::MAJOR == 4
        record = @resource.create!(resource_params.permit!)
      else
        record = @resource.create!(resource_params, without_protection: true)
      end

      render json: serialize_model(record, include: includes)
    end

    def update
      record = @resource.find(params[:id])

      if Rails::VERSION::MAJOR == 4
        record.update_attributes!(resource_params.permit!)
      else
        record.update_attributes!(resource_params, without_protection: true)
      end

      render json: serialize_model(record, include: includes)
    end

    def destroy
      @resource.destroy_all(id: params[:id])
      render nothing: true, status: 204
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_table_name(params[:collection])

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render json: {status: 404}, status: :not_found
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, params[:resource]).perform
    end

    def includes
      @resource
        .reflect_on_all_associations
        .select {|a| a.macro == :belongs_to && !a.options[:polymorphic] }
        .map {|a| a.name.to_s }
    end

  end
end
