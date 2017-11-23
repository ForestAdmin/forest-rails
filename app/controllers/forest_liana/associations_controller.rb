module ForestLiana
  class AssociationsController < ForestLiana::ApplicationController
    if Rails::VERSION::MAJOR < 4
      before_filter :find_resource
      before_filter :find_association
    else
      before_action :find_resource
      before_action :find_association
    end

    def index
      getter = HasManyGetter.new(@resource, @association, params)
      getter.perform

      respond_to do |format|
        format.json { render_jsonapi(getter) }
        format.csv { render_csv(getter, @association.klass) }
      end
    end

    def update
      updater = BelongsToUpdater.new(@resource, @association, params)
      updater.perform

      if updater.errors
        render serializer: nil, json: JSONAPI::Serializer.serialize_errors(
          updater.errors), status: 422
      else
        head :no_content
      end
    end

    def associate
      associator = HasManyAssociator.new(@resource, @association, params)
      associator.perform

      head :no_content
    end

    def dissociate
      dissociator = HasManyDissociator.new(@resource, @association, params)
      dissociator.perform

      head :no_content
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_collection_name(params[:collection])

      if @resource.nil? || !@resource.ancestors.include?(ActiveRecord::Base)
        render serializer: nil, json: {status: 404}, status: :not_found
      end
    end

    def find_association
      # Rails 3 wants a :sym argument.
      @association = @resource.reflect_on_association(
        params[:association_name].try(:to_sym))

      # Only accept "many" associations
      if @association.nil? ||
        ([:belongs_to, :has_one].include?(@association.macro) &&
         params[:action] == 'index')
        render serializer: nil, json: {status: 404}, status: :not_found
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, params[:resource], true).perform
    end

    def is_sti_model?
      @is_sti_model ||= (@association.klass.inheritance_column.present? &&
        @association.klass.columns.any? { |column| column.name == @association.klass.inheritance_column })
    end

    def get_record record
      is_sti_model? ? record.becomes(@association.klass) : record
    end

    def render_jsonapi getter
      records = getter.records.map { |record| get_record(record) }
      render serializer: nil, json: serialize_models(records,
        include: getter.includes, count: getter.count, params: params)
    end
  end
end
