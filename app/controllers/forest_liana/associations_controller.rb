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

      render serializer: nil, json: serialize_models(getter.records,
                                                     include: getter.includes,
                                                     count: getter.count,
                                                     params: params)
    end

    def update
      updater = BelongsToUpdater.new(@resource, @association, params)
      updater.perform

      render nothing: true, status: 204
    end

    def associate
      associator = HasManyAssociator.new(@resource, @association, params)
      associator.perform

      render nothing: true, status: 204
    end

    def dissociate
      dissociator = HasManyDissociator.new(@resource, @association, params)
      dissociator.perform

      render nothing: true, status: 204
    end

    private

    def find_resource
      @resource = SchemaUtils.find_model_from_table_name(params[:collection])

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
  end
end
