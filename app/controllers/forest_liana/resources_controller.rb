module ForestLiana
  class ResourcesController < ForestLiana::ApplicationController
    begin
      prepend ResourcesExtensions
    rescue NameError
    end

    before_action :find_resource

    def index
      getter = ResourcesGetter.new(@resource, params)
      getter.perform

      render serializer: nil, json: serialize_models(getter.records,
                                                     include: includes,
                                                     count: getter.count,
                                                     params: params)
    end

    def show
      getter = ResourceGetter.new(@resource, params)
      getter.perform

      render serializer: nil, json:
        serialize_model(getter.record, include: includes)
    end

    def create
      creator = ResourceCreator.new(@resource, params)
      creator.perform

      if creator.record.valid?
        render serializer: nil,
          json: serialize_model(creator.record, include: includes)
      else
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          creator.record.errors), status: 400
      end
    end

    def update
      updater = ResourceUpdater.new(@resource, params)
      updater.perform

      if updater.record.valid?
        render serializer: nil,
          json: serialize_model(updater.record, include: includes)
      else
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          updater.record.errors), status: 400
      end
    end

    def destroy
      @resource.destroy_all(id: params[:id])

      render nothing: true, status: 204
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_table_name(params[:collection])

      if @resource.nil? || !SchemaUtils.model_included?(@resource) ||
          !@resource.ancestors.include?(ActiveRecord::Base)
        render serializer: nil, json: {status: 404}, status: :not_found
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, params[:resource], true).perform
    end

    def includes
      SchemaUtils.one_associations(@resource)
        .select { |a| SchemaUtils.model_included?(a.klass) }
        .map { |a| a.name.to_s }
    end
  end
end
