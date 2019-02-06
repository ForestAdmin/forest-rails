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
      @tables_associated_to_relations_name = {}
      get_segment()
      compute_includes()
      @search_query_builder = SearchQueryBuilder.new(@params, @includes, @tables_associated_to_relations_name, @collection)

      prepare_query()
    end

    def perform
      @records = @records.eager_load(@includes)
      @records_sorted = sort_query
    end

    def count
      # NOTICE: For performance reasons, do not eager load the data if there is  no search or
      #         filters on associations.
      @records_count = @count_needs_includes ? @records.eager_load(@includes).count : @records.count
    end

    def query_for_batch
      @records
    end

    def records
      @records_sorted.offset(offset).limit(limit).to_a
    end

    def compute_includes
      associations_has_one = SchemaUtils.one_associations(@resource)
        .select { |association| SchemaUtils.model_included?(association.klass) }

      includes = associations_has_one.each do |association|
        if @tables_associated_to_relations_name[association.table_name].nil?
          @tables_associated_to_relations_name[association.table_name] = []
        end
        @tables_associated_to_relations_name[association.table_name] << association.name
      end

      includes = associations_has_one.map(&:name)
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
        @includes = (includes & @field_names_requested).concat(includes_for_smart_search)
      else
        @includes = includes
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
      column = nil
      order = 'DESC'

      if @params[:sort]
        @params[:sort].split(',').each do |field|
          order_detected = detect_sort_order(@params[:sort])
          order = order_detected.upcase
          field.slice!(0) if order_detected == :desc

          field = detect_reference(field)
          if field.index('.').nil?
            column = ForestLiana::AdapterHelper.format_column_name(@resource.table_name, field)
          else
            column = field
          end
        end
      elsif @resource.column_names.include?('created_at')
        column = ForestLiana::AdapterHelper.format_column_name(@resource.table_name, 'created_at')
      elsif @resource.column_names.include?('id')
        column = ForestLiana::AdapterHelper.format_column_name(@resource.table_name, 'id')
      end

      if column
        @records = @records.order(Arel.sql("#{column} #{order}"))
      else
        @records
      end
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
          segmentQuery = @params[:segmentQuery].gsub(/\;\s*$/, '')
          @records = @records.where(
            "#{@resource.table_name}.#{@resource.primary_key} IN (SELECT id FROM (#{segmentQuery}) as ids)"
          )
        rescue => error
          error_message = "Live Query Segment: #{error.message}"
          FOREST_LOGGER.error(error_message)
          raise ForestLiana::Errors::LiveQueryError.new(error_message)
        end
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
