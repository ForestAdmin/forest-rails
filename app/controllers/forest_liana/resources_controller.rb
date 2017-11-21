module ForestLiana
  class ResourcesController < ForestLiana::ApplicationController
    begin
      prepend ResourcesExtensions
    rescue NameError
    end

    rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found

    if Rails::VERSION::MAJOR < 4
      before_filter :find_resource
    else
      before_action :find_resource
    end

    def index
      getter = ForestLiana::ResourcesGetter.new(@resource, params)
      getter.perform

      respond_to do |format|
        format.json { render_jsonapi(getter) }
        format.csv { render_csv(getter, @resource) }
      end
    end

    def show
      getter = ForestLiana::ResourceGetter.new(@resource, params)
      getter.perform

      record = getter.record.becomes(@resource)
      render serializer: nil, json:
        serialize_model(record, include: includes(getter))
    end

    def create
      creator = ForestLiana::ResourceCreator.new(@resource, params)
      creator.perform

      if creator.errors
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          creator.errors), status: 400
      elsif creator.record.valid?
        record = creator.record.becomes(@resource)
        render serializer: nil,
          json: serialize_model(record, include: record_includes)
      else
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          creator.record.errors), status: 400
      end
    end

    def update
      updater = ForestLiana::ResourceUpdater.new(@resource, params)
      updater.perform

      if updater.errors
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          updater.errors), status: 400
      elsif updater.record.valid?
        record = updater.record.becomes(@resource)
        render serializer: nil,
          json: serialize_model(record, include: record_includes)
      else
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          updater.record.errors), status: 400
      end
    end

    def destroy
      @resource.destroy(params[:id])
      head :no_content
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_collection_name(params[:collection])

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

    def record_not_found
      head :not_found
    end

    def render_jsonapi getter
      records = getter.records.map { |record| record.becomes(@resource) }
      render serializer: nil, json: serialize_models(records,
        include: includes(getter), count: getter.count, params: params)
    end
  end
end
