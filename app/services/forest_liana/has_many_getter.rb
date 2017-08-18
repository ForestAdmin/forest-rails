module ForestLiana
  class HasManyGetter
    def initialize(resource, association, params)
      @resource = resource
      @association = association
      @params = params
      @field_names_requested = field_names_requested
    end

    def perform
      @records = @resource
        .unscoped
        .find(@params[:id])
        .send(@params[:association_name])
        .eager_load(includes)
      @records = search_query
      @records = sort_query
    end

    def search_query
      includesSymbols = includes.map { |association| association.to_sym }
      SearchQueryBuilder.new(@records, @params, includesSymbols).perform
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

    def count
      @records.to_a.length
    end

    private

    def field_names_requested
      return nil unless @params[:fields] && @params[:fields][@association.table_name]
      @params[:fields][@association.table_name].split(',')
        .map { |name| name.to_sym }
    end

    def association_table_name
      @resource.reflect_on_association(@params[:association_name].to_sym)
        .try(:table_name)
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
