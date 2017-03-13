module ForestLiana
  class ResourcesController < ForestLiana::ApplicationController
    begin
      prepend ResourcesExtensions
    rescue NameError
    end

    if Rails::VERSION::MAJOR < 4
      before_filter :find_resource
    else
      before_action :find_resource
    end

    def index
      getter = ResourcesGetter.new(@resource, params)
      getter.perform

      render serializer: nil, json: serialize_models(getter.records,
                                                     include: includes(getter),
                                                     count: getter.count,
                                                     params: params)
    end

    def show
      getter = ResourceGetter.new(@resource, params)
      getter.perform

      render serializer: nil, json:
        serialize_model(getter.record, include: includes(getter))
    end

    def create
      creator = ResourceCreator.new(@resource, params)
      creator.perform

      if creator.errors
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          creator.errors), status: 400
      elsif creator.record.valid?
        render serializer: nil,
          json: serialize_model(creator.record, include: record_includes)
      else
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          creator.record.errors), status: 400
      end
    end

    def update
      updater = ResourceUpdater.new(@resource, params)
      updater.perform

      if updater.errors
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          updater.errors), status: 400
      elsif updater.record.valid?
        render serializer: nil,
          json: serialize_model(updater.record, include: record_includes)
      else
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          updater.record.errors), status: 400
      end
    end

    def destroy
      @resource.destroy_all(id: params[:id])

      head :no_content
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_table_name(params[:collection])

      if @resource.nil? || !SchemaUtils.model_included?(@resource) ||
          !@resource.ancestors.include?(ActiveRecord::Base)
        render serializer: nil, json: {status: 404}, status: :not_found
      end
    end

    def includes(getter)
      getter.includes.map(&:to_s)
    end

    def record_includes
      SchemaUtils.one_associations(@resource)
        .select { |a| SchemaUtils.model_included?(a.klass) }
        .map { |a| a.name.to_s }
    end
  end
end
