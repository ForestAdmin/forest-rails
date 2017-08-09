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
        format.csv { render_csv(getter) }
      end
    end

    def show
      getter = ForestLiana::ResourceGetter.new(@resource, params)
      getter.perform

      render serializer: nil, json:
        serialize_model(getter.record, include: includes(getter))
    end

    def create
      creator = ForestLiana::ResourceCreator.new(@resource, params)
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
      updater = ForestLiana::ResourceUpdater.new(@resource, params)
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
      render serializer: nil, json: serialize_models(getter.records,
        include: includes(getter), count: getter.count, params: params)
    end

    def render_csv getter
      set_headers_file
      set_headers_streaming

      # response.status = 200
      params[:fields][@resource.table_name]
      field_names_requested = params[:fields][@resource.table_name].split(',')
                                              .map { |name| name.to_s }

      self.response_body = Enumerator.new do |content|
        content << CSV::Row.new(field_names_requested, field_names_requested, true).to_s
        getter.query_for_batch.find_in_batches() do |records|
          records.each do |record|
            json = serialize_model(record)
            attributes = json['data']['attributes']

            values = field_names_requested.map do |field_name|
              attributes[field_name]
            end
            content << CSV::Row.new(field_names_requested, values).to_s
          end
        end
      end
    end

    def set_headers_file
      csv_filename = "#{@resource.name}.csv"
      headers["Content-Type"] = "text/csv; charset=utf-8"
      headers["Content-disposition"] = %{attachment; filename="#{csv_filename}"}
      headers['Last-Modified'] = Time.now.ctime.to_s
      # TODO: Approximate the content length to have the download progress.
      # headers["Content-Length"] = "10000000"
    end

    def set_headers_streaming
      # NOTICE: From nginx doc: Setting this to "no" will allow unbuffered
      #         responses suitable for Comet and HTTP streaming applications
      headers['X-Accel-Buffering'] = 'no'
      headers["Cache-Control"] = "no-cache"
    end
  end
end
