module ForestLiana
  class BaseGetter
    include ForestLiana::RecordFindable

    def get_collection(collection_name)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    def get_resource
      @resource.instance_methods.include?(:really_destroyed?) ? @resource : @resource.unscoped
    end

    def includes_for_serialization
      includes_for_smart_belongs_to = @collection.fields_smart_belongs_to.map { |field| field[:field] }
      includes_for_smart_belongs_to &= @field_names_requested if @field_names_requested

      @includes.concat(includes_for_smart_belongs_to).map(&:to_s)
    end

    private

    def compute_includes
      @includes = ForestLiana::QueryHelper.get_one_association_names_symbol(@resource)
      @optional_includes = []
    end

    # A search predicate can only name an association the eager load actually joins;
    # analyze_associations drops the rest, leaving their table out of the FROM clause.
    def searchable_includes(resource)
      polymorphic, preload_loads = analyze_associations(resource)

      (@includes - polymorphic - preload_loads).map(&:to_sym)
    end

    def optimize_record_loading(resource, records, force_preload = true)
      polymorphic, preload_loads = analyze_associations(resource)
      result = records.eager_load(@includes.uniq - preload_loads - polymorphic - @optional_includes)

      result = result.preload(preload_loads) if Rails::VERSION::MAJOR >= 7 && force_preload

      result
    end

    def analyze_associations(resource)
      polymorphic = []
      preload_loads = @includes.uniq.select do |name|
        association = resource.reflect_on_association(name)
        if SchemaUtils.polymorphic?(association)
          polymorphic << association.name
          false
        else
          separate_database?(resource, association)
        end
      end + instance_dependent_associations(resource)

      [polymorphic, preload_loads]
    end

    def separate_database?(resource, association)
      return false if SchemaUtils.polymorphic?(association)

      target_model_database = association.klass.connection.pool.db_config.database
      resource_database = resource.connection.pool.db_config.database

      target_model_database != resource_database
    end

    def instance_dependent_associations(resource)
      @includes.select do |association_name|
        resource.reflect_on_association(association_name)&.scope&.arity&.positive?
      end
    end

    # NOTICE: The collection the records come from, which the projection is rooted on. It is the
    #         association target on the relationships routes, not the collection in the URL.
    def projected_resource
      @resource
    end

    def apply_projection(records, eager_loads)
      select = compute_select_fields(eager_loads)
      records = records.references(eager_loads) if eager_loads.any?

      # NOTICE: The _forest_admin_eager_load marker heading the select is only stripped by the
      #         JoinDependency override, which runs when the query really eager loads; it would
      #         otherwise reach the SQL as a column name.
      records.eager_loading? ? records.select(*select) : records.select(*select.drop(1))
    end

    # NOTICE: joined_relations names the relations this query joins, and so the only ones whose
    #         own columns can be projected here. Left nil, every requested relation is projected,
    #         which is what the list has always done.
    def compute_select_fields(joined_relations = nil)
      select = ['_forest_admin_eager_load']

      pk = projected_resource.primary_key
      if pk.is_a?(Array)
        pk.each { |key| select << "#{projected_resource.table_name}.#{key}" }
      else
        select << "#{projected_resource.table_name}.#{pk}"
      end

      # Include columns used in default ordering for batch cursor compatibility
      if projected_resource.respond_to?(:default_scoped) && projected_resource.default_scoped.order_values.any?
        projected_resource.default_scoped.order_values.each do |order_value|
          if order_value.is_a?(Arel::Nodes::Ordering)
            # Extract column name from Arel node
            column_name = order_value.expr.name if order_value.expr.respond_to?(:name)
            select << "#{projected_resource.table_name}.#{column_name}" if column_name
          elsif order_value.is_a?(String) || order_value.is_a?(Symbol)
            # Handle simple column names
            column_name = order_value.to_s.split(' ').first.split('.').last
            select << "#{projected_resource.table_name}.#{column_name}"
          end
        end
      end

      # Handle ActiveStorage associations from both @includes and @field_names_requested
      active_storage_associations_processed = Set.new

      (@includes + @field_names_requested).each do |path|
        association = path.is_a?(Symbol) ? projected_resource.reflect_on_association(path) : get_one_association(path)
        next unless association
        next if active_storage_associations_processed.include?(association.name)
        next unless is_active_storage_association?(association)

        # Include all columns from ActiveStorage tables to avoid initialization errors
        table_name = association.table_name
        association.klass.column_names.each do |column_name|
          select << "#{table_name}.#{column_name}"
        end

        # Include the foreign key from the main resource (e.g., blob_id, record_id)
        if association.macro == :belongs_to || association.macro == :has_one
          foreign_keys = Array(association.foreign_key)
          foreign_keys.each do |fk|
            select << "#{projected_resource.table_name}.#{fk}"
          end
        end

        active_storage_associations_processed.add(association.name)
      end

      @field_names_requested.each do |path|
        association = get_one_association(path)
        if association
          through_chain = []
          current_association = association
          while current_association.options[:through]
            through_chain << current_association.options[:through]
            current_association = get_one_association(current_association.options[:through])
          end

          # Skip ActiveStorage associations - already processed above
          next if is_active_storage_association?(association)

          # For :through associations, recursively add all intermediate foreign keys
          if through_chain.any?
            current_resource = projected_resource
            through_chain.reverse.each do |through_name|
              through_assoc = current_resource.reflect_on_association(through_name)

              if through_assoc
                if through_assoc.options[:through]
                  direct_through_name = through_assoc.options[:through]
                  direct_assoc = current_resource.reflect_on_association(direct_through_name)

                  if direct_assoc && (direct_assoc.macro == :belongs_to || direct_assoc.macro == :has_one)
                    fks = Array(direct_assoc.foreign_key)
                    fks.each do |fk|
                      select << "#{current_resource.table_name}.#{fk}"
                    end
                  end
                else
                  # Direct association (not nested through)
                  if through_assoc.macro == :belongs_to || through_assoc.macro == :has_one
                    fks = Array(through_assoc.foreign_key)
                    fks.each do |fk|
                      select << "#{current_resource.table_name}.#{fk}"
                    end
                  end
                end

                # Move to the next level in the chain
                current_resource = through_assoc.klass if through_assoc.klass
              end
            end
          else
            # Direct association (not :through)
            if SchemaUtils.polymorphic?(association)
              select << "#{projected_resource.table_name}.#{association.foreign_type}"
            end

            if association.macro == :belongs_to || association.macro == :has_one
              fks = Array(association.foreign_key)
              fks.each do |fk|
                select << "#{projected_resource.table_name}.#{fk}"
              end
            end
          end
        end

        fields = @params[:fields]&.[](path)&.split(',')
        if fields
          association = get_one_association(path)

          # NOTICE: A polymorphic relation is loaded target by target, out of this query, so its
          #         own fields cannot reach this select — reading its table_name here would only
          #         raise. They still apply to the serialization. A path naming no to-one
          #         relation is dropped, the way the fields[] query params already drop it.
          next if association.nil? || is_active_storage_association?(association) ||
            SchemaUtils.polymorphic?(association)

          # NOTICE: A relation the query does not join is loaded by a SELECT of its own, out of
          #         reach of this projection: naming its columns here would only break the SQL.
          next if joined_relations && !joined_relations.include?(association.name)

          table_name = association.table_name

          fields.each do |association_path|
            next if association_path == 'id'

            if ForestLiana::SchemaHelper.is_smart_field?(association.klass, association_path)
              association.klass.attribute_names.each { |attribute| select << "#{table_name}.#{attribute}" }
            else
              select << "#{table_name}.#{association_path}"
            end
          end
        else
          # Only add as column if it's not an association
          # Associations are handled by the through chain logic above
          unless association
            select << "#{projected_resource.table_name}.#{path}"
          end
        end
      end

      select.uniq
    end

    def get_one_association(name)
      # Handle composite primary keys - name might be an Array
      name_sym = name.is_a?(Array) ? name : name.to_sym
      ForestLiana::QueryHelper.get_one_associations(projected_resource)
                              .select { |association| association.name == name_sym }
                              .first
    end

    def is_active_storage_association?(association)
      return false unless association
      return false if SchemaUtils.polymorphic?(association)

      klass_name = association.klass.name
      klass_name == 'ActiveStorage::Attachment' ||
      klass_name == 'ActiveStorage::Blob' ||
      klass_name.start_with?('ActiveStorage::')
    end
  end
end
