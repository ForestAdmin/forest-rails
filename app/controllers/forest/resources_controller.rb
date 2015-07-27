module Forest
  class ResourcesController < Forest::ApplicationController

    before_filter :find_resource
    before_filter :define_serializers

    def index
      getter = ResourcesGetter.new(@resource, params)
      getter.perform

      render json: serialize_models(getter.records.limit(10),
                                    include: includes,
                                    count: getter.records.count)
    end

    def show
      getter = ResourceGetter.new(@resource, params)
      getter.perform

      render json: serialize_model(getter.record, include: includes)
    end

    def create
      record = @resource.create!(resource_params)
      render json: record, serializer: @serializer, adapter: :json_api,
        include: includes
    end

    def update
      record = @resource.find(params[:id])
      record.update_attributes!(resource_params)
      render json: record, serializer: @serializer, adapter: :json_api,
        include: includes
    end

    def destroy
      @resource.destroy_all(id: params[:id])
      render nothing: true, status: 204
    end

    private

    def find_resource
      @resource_plural_name = params[:resource]
      @resource_singular_name = @resource_plural_name.singularize
      @resource_class_name = @resource_singular_name.classify

      begin
        @resource = @resource_class_name.constantize
      rescue
      end

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render json: {status: 404}, status: :not_found
      end
    end

    def define_serializers
      @serializer = SerializerFactory.new.serializer_for(@resource)
    end

    def resource_params
      ResourceDeserializer.new(@resource, params).perform
    end

    def includes
      @resource
        .reflect_on_all_associations
        .select {|a| a.macro == :belongs_to && !a.options[:polymorphic] }
        .map {|a| a.name.to_s }
    end

  end
end
