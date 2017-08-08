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
      respond_to do |format|
        format.json { render_jsonapi }
        format.csv { render_csv }
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

    def render_jsonapi
      getter = ForestLiana::ResourcesGetter.new(@resource, params)
      getter.perform

      render serializer: nil, json: serialize_models(getter.records,
                                                     include: includes(getter),
                                                     count: getter.count,
                                                     params: params)
    end

    def render_csv
      set_file_headers

      # response.status = 200

      csv_lines
    end

    def set_file_headers
      csv_filename = "#{@resource.name}.csv"
      headers["Content-Type"] = "text/csv; charset=utf-8"
      headers["Content-disposition"] = %{attachment; filename="#{csv_filename}"}
      headers['Last-Modified'] = Time.now.ctime.to_s
      # headers["Content-Length"] = "10000000"
    end

    def set_streaming_headers
      #nginx doc: Setting this to "no" will allow unbuffered responses suitable for Comet and HTTP streaming applications
      headers['X-Accel-Buffering'] = 'no'
      headers["Cache-Control"] = "no-cache"
      # headers.delete("Content-Length")
    end

    def csv_lines
      set_streaming_headers
      self.response_body = Enumerator.new do |y|
        # y << CSV::Row.new([:id], ['ID'], true).to_s
        # y << Transaction.csv_header.to_s
        @resource.find_in_batches() do |records|
          records.each do |record|
            y << CSV::Row.new([:id, :firstname, :lastname], [record.id, record.firstname, record.lastname]).to_s
          end
        end
      end

    end
  end
end
