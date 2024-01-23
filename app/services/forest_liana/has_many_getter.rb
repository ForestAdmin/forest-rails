module ForestLiana
  class HasManyGetter < BaseGetter
    attr_reader :search_query_builder
    attr_reader :includes
    attr_reader :records_count

    def initialize(resource, association, params, forest_user)
      @resource = resource
      @association = association
      @params = params
      @collection_name = ForestLiana.name_for(model_association)
      @field_names_requested = field_names_requested
      @collection = get_collection(@collection_name)
      compute_includes()
      includes_symbols = @includes.map { |include| include.to_sym }
      @search_query_builder = SearchQueryBuilder.new(@params, includes_symbols, @collection, forest_user)

      prepare_query()
    end

    def perform
      @records
    end

    def count
      @records_count = @records.count
    end

    def query_for_batch
      @records
    end

    def records
      @records.limit(limit).offset(offset)
    end

    private

    def compute_includes
      @includes = @association.klass
        .reflect_on_all_associations
        .select do |association|

          if SchemaUtils.polymorphic?(association)
            inclusion = SchemaUtils.polymorphic_models(association)
                                   .all? { |model| SchemaUtils.model_included?(model) } &&
              [:belongs_to, :has_and_belongs_to_many].include?(association.macro)
          else
            inclusion = SchemaUtils.model_included?(association.klass) &&
              [:belongs_to, :has_and_belongs_to_many].include?(association.macro)
          end

            if @field_names_requested
              inclusion && @field_names_requested.include?(association.name)
            else
              inclusion
            end
          end
        .map { |association| association.name }
    end

    def field_names_requested
      return nil unless @params[:fields] && @params[:fields][@collection_name]
      @params[:fields][@collection_name].split(',')
        .map { |name| name.to_sym }
    end

    def model_association
      @resource.reflect_on_association(@params[:association_name].to_sym).klass
    end

    def prepare_query
      association = get_resource().find(@params[:id]).send(@params[:association_name])
      @records = optimize_record_loading(association, @search_query_builder.perform(association))
    end

    def offset
      return 0 unless pagination?

      number = @params[:page][:number]
      if number && number.to_i > 0
        (number.to_i - 1) * limit
      else
        0
      end
    end

    def limit
      if @params[:page] && @params[:page][:size]
        @params[:page][:size].to_i
      else
        5
      end
    end

    def pagination?
      @params[:page] && @params[:page][:number]
    end
  end
end
