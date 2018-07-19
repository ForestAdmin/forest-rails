module ForestLiana
  class HasManyGetter < BaseGetter
    attr_reader :search_query_builder
    attr_reader :records_count

    def initialize(resource, association, params)
      @resource = resource
      @association = association
      @params = params
      @collection_name = ForestLiana.name_for(model_association)
      @field_names_requested = field_names_requested
      @collection = get_collection(@collection_name)
      includes_symbols = includes.map { |association| association.to_sym }
      @search_query_builder = SearchQueryBuilder.new(@params, includes_symbols, @collection)

      prepare_query()
    end

    def perform
      @records = search_query
      @records = sort_query
    end

    def count
      @records_count = @records.count
    end

    def search_query
      @search_query_builder.perform(@records)
    end

    def includes
      @association.klass
        .reflect_on_all_associations
        .select do |association|
          inclusion = !association.options[:polymorphic] &&
            SchemaUtils.model_included?(association.klass) &&
            [:belongs_to, :has_and_belongs_to_many].include?(association.macro)

          if @field_names_requested
            inclusion && @field_names_requested.include?(association.name)
          else
            inclusion
          end
        end
        .map { |association| association.name.to_s }
    end

    def query_for_batch
      @records
    end

    def records
      @records.limit(limit).offset(offset)
    end

    private

    def field_names_requested
      return nil unless @params[:fields] && @params[:fields][@collection_name]
      @params[:fields][@collection_name].split(',')
        .map { |name| name.to_sym }
    end

    def association_table_name
      model_association.try(:table_name)
    end

    def model_association
      @resource.reflect_on_association(@params[:association_name].to_sym).klass
    end

    def prepare_query
      @records = get_resource()
        .find(@params[:id])
        .send(@params[:association_name])
        .eager_load(includes)
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

    def sort_query
      if @params[:sort]
        field = @params[:sort]
        order = detect_sort_order(field)
        field.slice!(0) if order == :desc

        @records = @records
          .order("#{association_table_name}.#{field} #{order.upcase}")
      else
        @records
      end
    end

    def detect_sort_order(field)
      return (if field[0] == '-' then :desc else :asc end)
    end

  end
end
