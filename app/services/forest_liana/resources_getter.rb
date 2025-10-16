module ForestLiana
  class ResourcesGetter < BaseGetter
    attr_reader :search_query_builder, :includes, :records_count

    def initialize(resource, params, forest_user)
      @resource = resource
      @params = params
      @user = forest_user
      @count_needs_includes = false
      @collection_name = ForestLiana.name_for(@resource)
      @collection = get_collection(@collection_name)
      @fields_to_serialize = get_fields_to_serialize
      @field_names_requested = field_names_requested
      @segment = get_segment
      compute_includes
      @search_query_builder = SearchQueryBuilder.new(@params, @includes, @collection, @user)

      prepare_query
    end

    def self.get_ids_from_request(params, user)
      attributes = params.dig('data', 'attributes')
      return attributes[:ids] if attributes&.fetch(:all_records, false) == false && attributes[:ids]

      attributes = merge_subset_query(attributes)
      resources_getter = initialize_resources_getter(attributes, user)
      ids = fetch_ids(resources_getter)

      filter_excluded_ids(ids, attributes[:all_records_ids_excluded])
    end

    def perform
      polymorphic_association, preload_loads = analyze_associations(@resource)
      includes = @includes.uniq - polymorphic_association - preload_loads - @optional_includes
      has_smart_fields = Array(@params.dig(:fields, @collection_name)&.split(',')).any? do |field|
        ForestLiana::SchemaHelper.is_smart_field?(@resource, field)
      end

      if includes.empty? || has_smart_fields
        @records = optimize_record_loading(@resource, @records, false)
      else
        select = compute_select_fields
        @records = optimize_record_loading(@resource, @records, false).references(includes).select(*select)
      end

      @records
    end

    def count
      @records_count = @count_needs_includes ? optimized_count : @records.count
    end

    def query_for_batch
      @records
    end

    def records
      records = @records.offset(offset).limit(limit).to_a
      polymorphic_association, preload_loads = analyze_associations(@resource)

      if polymorphic_association.any? && Rails::VERSION::MAJOR >= 7
        preloader = ActiveRecord::Associations::Preloader.new(records: records, associations: polymorphic_association)
        preloader.loaders
        preloader.branches.each do |branch|
          branch.loaders.each do |loader|
            records_by_owner = loader.records_by_owner
            records_by_owner.each do |record, association|
              record_index =  records.find_index { |r| r.id == record.id }
              records[record_index].define_singleton_method(branch.association) do
                association.first
              end
            end
          end
        end
      end

      records
    end

    def columns_for_cross_database_association(association_name)
      association = @resource.reflect_on_association(association_name)

      # Always include all columns of the associated model to avoid missing attribute errors
      columns = association.klass.column_names.map(&:to_sym)

      # Ensure the foreign key is present for manual binding (especially for has_one)
      if association.macro == :has_one
        foreign_keys = Array(association.foreign_key).map(&:to_sym)
        columns.concat(foreign_keys)
      end

      columns.uniq
    end

    def compute_includes
      associations_has_one = ForestLiana::QueryHelper.get_one_associations(@resource)

      @optional_includes = []
      if @field_names_requested && @params['searchExtended'].to_i != 1
        includes = associations_has_one.map do |association|
          association_name = association.name.to_s

          fields = @params[:fields]&.[](association_name)&.split(',')
          if fields&.size == 1 && fields.include?(association.klass.primary_key)
            # Handle composite foreign keys
            foreign_keys = Array(association.foreign_key)
            foreign_keys.each { |fk| @field_names_requested << fk }
            @optional_includes << association.name
          end

          association.name
        end

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

        @includes = (includes & @field_names_requested).concat(includes_for_smart_search)
      else
        @includes = associations_has_one
        # Avoid eager loading has_one associations pointing to a different database as ORM can't join cross databases
                      .reject { |association| separate_database?(@resource, association) }
                      .map(&:name)
      end
    end

    def includes_for_serialization
      super & @fields_to_serialize.map(&:to_s)
    end

    private

    def get_fields_to_serialize
      @params.dig(:fields, @collection_name)&.split(',')&.map(&:to_sym) || []
    end

    def get_segment
      @collection.segments.find { |segment| segment.name == @params[:segment] } if @params[:segment]
    end

    def field_names_requested
      return [] unless @params.dig(:fields, @collection_name)

      associations_for_query = extract_associations_from_filter
      associations_for_query << @params[:sort].split('.').first.to_sym if @params[:sort]&.include?('.')
      @fields_to_serialize | associations_for_query
    end

    def extract_associations_from_filter
      associations = []

      filters = @params[:filters]
      filters = JSON.parse(filters) if filters.is_a?(String)

      conditions = []

      if filters.is_a?(Hash) && filters.key?('conditions')
        conditions = filters['conditions']
      elsif filters.is_a?(Hash) && filters.key?('field')
        conditions = [filters]
      end

      conditions.each do |condition|
        field = condition['field']
        if field&.include?(':')
          associations << field.split(':').first.to_sym
          @count_needs_includes = true
        end
      end

      @count_needs_includes = true if @params[:search]

      associations.uniq
    end

    def prepare_query
      @records = get_resource

      if @segment
        @records = apply_segment(@records)
      end

      apply_live_query_segment if @params[:segmentQuery]
      @records = search_query
    end

    def optimized_count
      optimize_record_loading(@resource, @records).count
    end

    def apply_segment(records)
      return records.send(@segment.scope) if @segment.scope
      return records.where(@segment.where.call) if @segment.where

      records
    end

    def apply_live_query_segment
      LiveQueryChecker.new(@params[:segmentQuery], 'Live Query Segment').validate

      begin
        segment_query = @params[:segmentQuery].gsub(/\;\s*$/, '')
        ScopeManager.inject_context_variables_on_query(segment_query, @user)

        @records = @records.where(
          "#{@resource.table_name}.#{@resource.primary_key} IN (SELECT id FROM (#{segment_query}) as ids)"
        )
      rescue => error
        handle_live_query_error(error)
      end
    end

    def handle_live_query_error(error)
      error_message = "Live Query Segment: #{error.message}"
      FOREST_REPORTER.report error
      FOREST_LOGGER.error(error_message)
      raise ForestLiana::Errors::LiveQueryError.new(error_message)
    end

    def self.merge_subset_query(attributes)
      attributes.merge(attributes[:all_records_subset_query].dup.to_unsafe_h)
    end

    def self.initialize_resources_getter(attributes, user)
      if related_data?(attributes)
        HasManyGetter.new(*related_data_params(attributes, user))
      else
        ResourcesGetter.new(SchemaUtils.find_model_from_collection_name(attributes[:collection_name]), attributes, user)
      end
    end

    def self.related_data?(attributes)
      attributes[:parent_collection_id] && attributes[:parent_collection_name] && attributes[:parent_association_name]
    end

    def self.related_data_params(attributes, user)
      parent_model = SchemaUtils.find_model_from_collection_name(attributes[:parent_collection_name])
      model = parent_model.reflect_on_association(attributes[:parent_association_name].to_sym)

      [
        parent_model,
        model,
        attributes.merge(
          collection: attributes[:parent_collection_name],
          id: attributes[:parent_collection_id],
          association_name: attributes[:parent_association_name]
        ),
        user
      ]
    end

    def self.fetch_ids(resources_getter)
      ids = []
      resources_getter.query_for_batch.find_in_batches { |records| ids += records.map(&:id) }

      ids
    end

    def self.filter_excluded_ids(ids, ids_excluded)
      ids_excluded ? ids.reject { |id| ids_excluded.map(&:to_s).include?(id.to_s) } : ids
    end

    def search_query
      @search_query_builder.perform(@records)
    end

    def offset
      return 0 unless pagination?

      number = @params.dig(:page, :number)
      number.to_i.positive? ? (number.to_i - 1) * limit : 0
    end

    def limit
      @params.dig(:page, :size)&.to_i || 10
    end

    def pagination?
      @params[:page]&.dig(:number)
    end

    def compute_select_fields
      select = ['_forest_admin_eager_load']
      @field_names_requested.each do |path|
        association = get_one_association(path)
        if association
          while association.options[:through]
            association = get_one_association(association.options[:through])
          end

          if SchemaUtils.polymorphic?(association)
            select << "#{@resource.table_name}.#{association.foreign_type}"
          end

          # Handle composite foreign keys
          foreign_keys = Array(association.foreign_key)
          foreign_keys.each do |fk|
            select << "#{@resource.table_name}.#{fk}"
          end
        end

        fields = @params[:fields]&.[](path)&.split(',')
        if fields
          association = get_one_association(path)
          table_name = association.table_name

          fields.each do |association_path|
            if ForestLiana::SchemaHelper.is_smart_field?(association.klass, association_path)
              association.klass.attribute_names.each { |attribute| select << "#{table_name}.#{attribute}" }
            else
              select << "#{table_name}.#{association_path}"
            end
          end
        else
          select << "#{@resource.table_name}.#{path}"
        end
      end

      select.uniq
    end

    def get_one_association(name)
      # Handle composite primary keys - name might be an Array
      name_sym = name.is_a?(Array) ? name : name.to_sym
      ForestLiana::QueryHelper.get_one_associations(@resource)
                              .select { |association| association.name == name_sym }
                              .first
    end
  end
end
