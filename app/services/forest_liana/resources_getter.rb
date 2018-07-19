module ForestLiana
  class ResourcesGetter < BaseGetter
    attr_reader :search_query_builder
    attr_reader :records_count

    def initialize(resource, params)
      @resource = resource
      @params = params
      @count_needs_includes = false
      @collection_name = ForestLiana.name_for(@resource)
      @collection = get_collection(@collection_name)
      @field_names_requested = field_names_requested
      get_segment()
      @search_query_builder = SearchQueryBuilder.new(@params, includes, @collection)

      prepare_query()
    end

    def perform
      @records = @records.eager_load(includes)
      @records_sorted = sort_query
    end

    def count
      # NOTICE: For performance reasons, do not eager load the data if there is
      #         no search or filters on associations.
      @records_count = @count_needs_includes ? @records.eager_load(includes).count : @records.count
    end

    def query_for_batch
      @records
    end

    def records
      @records_sorted.offset(offset).limit(limit).to_a
    end

    def includes
      includes = SchemaUtils.one_associations(@resource)
        .select { |association| SchemaUtils.model_included?(association.klass) }
        .map(&:name)
      includes_for_smart_search = []

      if @collection && @collection.search_fields
        includes_for_smart_search = @collection.search_fields
          .select { |field| field.include? '.' }
          .map { |field| field.split('.').first.to_sym }

        includes_has_many = SchemaUtils.many_associations(@resource)
          .select { |association| SchemaUtils.model_included?(association.klass) }
          .map(&:name)

        includes_for_smart_search = includes_for_smart_search & includes_has_many
      end

      if @field_names_requested
        (includes & @field_names_requested).concat(includes_for_smart_search)
      else
        includes
      end
    end

    private

    def get_segment
      if @params[:segment]
        @segment = @collection.segments.find do |segment|
          segment.name == @params[:segment]
        end
      end
      @segment ||= nil
    end

    def field_names_requested
      return nil unless @params[:fields] && @params[:fields][@collection_name]

      associations_for_query = []

      # NOTICE: Populate the necessary associations for filters
      if @params[:filter]
        @params[:filter].each do |field, values|
          if field.include? ':'
            associations_for_query << field.split(':').first.to_sym
            @count_needs_includes = true
          end
        end
      end

      @count_needs_includes = true if @params[:search]

      if @params[:sort] && @params[:sort].include?('.')
        associations_for_query << @params[:sort].split('.').first.to_sym
      end

      field_names = @params[:fields][@collection_name].split(',').map { |name| name.to_sym }
      field_names | associations_for_query
    end

    def search_query
      @search_query_builder.perform(@records)
    end

    def sort_query
      if @params[:sort]
        @params[:sort].split(',').each do |field|
          order = detect_sort_order(@params[:sort])
          field.slice!(0) if order == :desc

          field = detect_reference(field)
          if field.index('.').nil?
            @records = @records
              .order("#{@resource.table_name}.#{field} #{order.upcase}")
          else
            @records = @records.order("#{field} #{order.upcase}")
          end
        end
      elsif @resource.column_names.include?('created_at')
        @records = @records.order("#{@resource.table_name}.created_at DESC")
      elsif @resource.column_names.include?('id')
        @records = @records.order("#{@resource.table_name}.id DESC")
      end

      @records
    end

    def prepare_query
      @records = get_resource

      if @segment && @segment.scope
        @records = @records.send(@segment.scope)
      elsif @segment && @segment.where
        @records = @records.where(@segment.where.call())
      end

      # NOTICE: Live Query mode
      if @params[:segmentQuery]
        LiveQueryChecker.new(@params[:segmentQuery], 'Live Query Segment').validate()

        begin
          results = ActiveRecord::Base.connection.execute(@params[:segmentQuery])
        rescue => error
          error_message = "Live Query Segment: #{error.message}"
          FOREST_LOGGER.error(error_message)
          raise ForestLiana::Errors::LiveQueryError.new(error_message)
        end

        record_ids = results.to_a.map { |record| record['id'] }
        @records = @records.where(id: record_ids)
      end

      @records = search_query
    end

    def detect_sort_order(field)
      return (if field[0] == '-' then :desc else :asc end)
    end

    def detect_reference(param)
      ref, field = param.split('.')

      if ref && field
        association = @resource.reflect_on_all_associations
          .find {|a| a.name == ref.to_sym }

        if association
          ForestLiana::AdapterHelper
            .format_column_name(association.table_name, field)
        else
          param
        end
      else
        param
      end
    end

    def association?(field)
      @resource.reflect_on_association(field.to_sym).present?
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
      return 10 unless pagination?

      if @params[:page][:size]
        @params[:page][:size].to_i
      else
        10
      end
    end

    def pagination?
      @params[:page] && @params[:page][:number]
    end

  end
end
