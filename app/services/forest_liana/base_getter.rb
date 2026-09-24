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

      # A new array, never @includes itself: a smart belongs_to has no ActiveRecord reflection,
      # and analyze_associations reflects on everything @includes holds.
      (@includes + includes_for_smart_belongs_to).map(&:to_s)
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

      if Rails::VERSION::MAJOR >= 7 && force_preload
        result = result.preload(selectable_preloads(result, preload_loads))
      end

      result
    end

    # The relation half of a smart field's dependencies:. Its column half reaches the select
    # (compute_select_fields); a path instead names an association the getter walks inside
    # instance_eval, once per record — loaded here in one query for the whole page instead.
    def apply_smart_field_preloads(records)
      preloads = smart_field_preloads
      preloads = preloads.slice(*selectable_preloads(records, preloads.keys))

      preloads.empty? ? records : records.preload(preloads)
    end

    def smart_field_preloads
      return {} if @collection.nil?

      @collection.smart_field_dependency_relation_paths(serialized_smart_field_names)
                 .reject { |path| skip_preload?(path) }
                 .reduce({}) { |tree, path| tree.deep_merge(nest_relations(path.relations)) }
    end

    # Without a fields[] param every smart field is serialized, so every declared path is needed;
    # with one, only the requested subset — a collection carrying ten declared fields must not
    # preload the nine relations the request never named, or this trades an N+1 for a constant
    # over-fetch. @field_names_requested is [] on the getters that always set it and nil on the
    # one that leaves it unset without a projection, hence #present? rather than #any?.
    def serialized_smart_field_names
      return @field_names_requested if @field_names_requested.present?

      @collection.computed_smart_fields.map { |field| field[:field] }
    end

    # ['account', 'owner'] => { account: { owner: {} } }, the nested form #preload takes.
    def nest_relations(relations)
      relations.reverse.reduce({}) { |children, name| { name.to_sym => children } }
    end

    # Keyed on (collection, path, reason) for the life of the process rather than per getter
    # instance, which is one per request: the same declaration would otherwise log the same line
    # again on every page of every list.
    PRELOAD_SKIPS_WARNED = Set.new

    # SmartFieldDependencies.validate! already rejects at boot a path that resolves to nothing or
    # crosses a polymorphic relation — re-checked here so that a collection reaching this outside
    # that pass degrades to the lazy load it has always done, rather than raising once per request.
    #
    # Every branch reinstates the N+1 this file exists to remove, and what stops a declaration
    # working is usually a change made elsewhere months later — a scope added to an association a
    # path happens to cross. Logged once per process so that regression is visible rather than
    # inferred from a latency graph.
    def skip_preload?(path)
      reason = preload_skip_reason(path)
      return false if reason.nil?

      warn_preload_skipped(path, reason)
      true
    end

    # nil when the path can be preloaded, otherwise the reason it cannot, for the log line.
    def preload_skip_reason(path)
      model = projected_resource

      path.relations.each do |name|
        association = model.reflect_on_association(name.to_sym)
        return "\"#{name}\" is not an association of #{model.name}" if association.nil?
        return "\"#{name}\" is polymorphic" if SchemaUtils.polymorphic?(association)

        scoped = instance_dependent_hop(association)
        return "\"#{scoped.name}\" has an instance-dependent scope, which Rails " \
          "#{Rails::VERSION::STRING} cannot preload" if scoped

        model = association.klass
      end

      nil
    # Every broken shape reachable from here arrives as a NameError, on 6.1 through 8.1 alike: a
    # :through naming a hop that does not exist, one whose source does not, a class_name pointing
    # at no model all answer NoMethodError or NameError off #klass. Nothing here calls
    # check_validity!, which is what raises HasManyThroughAssociationNotFoundError and its
    # siblings, so ActiveRecordError catches nothing known — kept as a net rather than for a
    # caller, and whatever does land there is named in the log below instead of being silently
    # indistinguishable from "the relation does not exist".
    rescue NameError, ActiveRecord::ActiveRecordError => exception
      "#{exception.class}: #{exception.message}"
    end

    # Rails 6.1's Preloader refuses an instance-dependent scope outright; optimize_record_loading
    # gates its own preload on the same version for the same reason. Falling back to the lazy load
    # keeps today's N+1 there — slower than it could be, never wrong. Mirrors check_preloadable!'s
    # own `scope.arity == 0`, which a scope taking an optional or splat argument (arity -1) fails
    # just as surely as one taking a required one.
    #
    # A :through hop is not preloaded directly: Preloader::ThroughAssociation re-enters the
    # preloader on the through and source reflections, each of which check_preloadable! checks in
    # turn. So the whole chain has to be walked, not only the hop the path names — its raise is an
    # ArgumentError at query-resolution time, which no rescue here can reach and which takes down
    # the list rather than the one field.
    def instance_dependent_hop(association)
      return nil if Rails::VERSION::MAJOR >= 7

      [association, *through_chain(association)].find do |reflection|
        reflection.scope && !reflection.scope.arity.zero?
      end
    end

    def through_chain(association)
      return [] unless association.through_reflection?

      [association.through_reflection, association.source_reflection].flat_map do |reflection|
        [reflection, *through_chain(reflection)]
      end
    end

    def warn_preload_skipped(path, reason)
      declaration = (path.relations + [path.column]).compact.join(':')
      return unless PRELOAD_SKIPS_WARNED.add?([@collection&.name, declaration, reason])

      FOREST_LOGGER.warn "The \"#{declaration}\" dependency of the \"#{@collection&.name}\" " \
        "collection cannot be preloaded (#{reason}) — the relation is loaded once per record " \
        'instead, as it was before it was declared.'
    end

    # Rails 7 introduced records:/associations: keyword preloading with a branches/loaders
    # structure this method walks to define a singleton accessor per polymorphic target; 6.1's
    # Preloader#preload takes the same records/associations positionally and returns the loaders
    # directly (one per target class among the polymorphic records), without that branch grouping
    # - preloaded one association at a time here so its name is already known, not read back off
    # a branch this version's Preloader doesn't expose.
    #
    # #call rather than #loaders on 7+: reading records_by_owner off a loader does load it, so the
    # singleton readers below are right either way — but only #call reaches Batch, which is what
    # runs each loader and so what writes the targets into the association cache too. 6.1's
    # #preload always did. Without it the two versions disagree on what a preloaded polymorphic
    # relation leaves behind, and get_record's becomes() — which carries the cache, not another
    # instance's singleton class — drops the target on 7+ only.
    def preload_polymorphic_associations(records, associations)
      return if associations.empty? || records.empty?

      if Rails::VERSION::MAJOR >= 7
        preloader = ActiveRecord::Associations::Preloader.new(records: records, associations: associations)
        preloader.call
        preloader.branches.each do |branch|
          branch.loaders.each { |loader| assign_preloaded_targets(branch.association, loader.records_by_owner) }
        end
      else
        associations.each do |association|
          ActiveRecord::Associations::Preloader.new.preload(records, association).each do |loader|
            assign_preloaded_targets(association, loader.records_by_owner)
          end
        end
      end
    end

    # To-one only: a filter puts a to-many in @includes too, and preloading that would read every
    # child row of a page that never displays them.
    PRELOADABLE_CROSS_DATABASE_MACROS = [:belongs_to, :has_one].freeze

    def cross_database_associations(resource)
      @includes.uniq.select do |name|
        association = resource.reflect_on_association(name)
        next false if association.nil? || SchemaUtils.polymorphic?(association)
        next false unless PRELOADABLE_CROSS_DATABASE_MACROS.include?(association.macro)

        separate_database?(resource, association) && instance_dependent_hop(association).nil?
      end
    end

    # Same version split as preload_polymorphic_associations. Nothing reads the loaders back here:
    # a plain relation lands in the association cache, where the serializer finds it.
    def preload_cross_database_associations(records, associations)
      return if associations.empty? || records.empty?

      associations = associations.reject { |name| missing_preload_key?(records, name) }
      return if associations.empty?

      if Rails::VERSION::MAJOR >= 7
        ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
      else
        ActiveRecord::Associations::Preloader.new.preload(records, associations)
      end
    end

    # A missing key raises while resolving the query, out of MissingAttributeValve's reach, and
    # takes down the whole list rather than the one field (PRD-1316 from the other direction).
    # Not only a belongs_to: a has_one reads its owner key off this row too when it declares a
    # primary_key of its own. Per record class, not projected_resource, because that is how the
    # Preloader resolves the reflection — one record per class is enough, the select being shared.
    def missing_preload_key?(records, association_name)
      records.group_by(&:class).any? do |klass, klass_records|
        association = klass._reflect_on_association(association_name)
        next false if association.nil?

        missing = preload_owner_keys(association).reject { |key| klass_records.first.has_attribute?(key) }
        next false if missing.empty?

        warn_cross_database_preload_skipped(association_name, missing)
        true
      end
    end

    def warn_cross_database_preload_skipped(association_name, missing_keys)
      reason = "its \"#{missing_keys.join('", "')}\" key is not in the projected select"
      return unless PRELOAD_SKIPS_WARNED.add?([@collection&.name, association_name, reason])

      FOREST_LOGGER.warn "The \"#{association_name}\" relation of the \"#{@collection&.name}\" " \
        "collection lives in another database and cannot be preloaded (#{reason}) — it falls back " \
        'to the lazy load, which cannot read that key either and resolves to a null relation.'
    end

    # The same question as missing_preload_key?, asked of a relation rather than of a page. A
    # preload attached to a relation resolves after this method returns — per batch for an export,
    # on #load for a list — so there is no record to test the key against, only the select the
    # relation already carries. An empty one is SELECT *, which can never be missing anything; a
    # narrowed one (a segment scope's .select, a default_scope's) can, and reading a key that is
    # not there raises while resolving the query, out of MissingAttributeValve's reach, taking
    # down the whole export where the lazy load it replaces degraded to a null relation.
    def selectable_preloads(records, names)
      return names if names.empty? || !records.respond_to?(:select_values)
      return names if records.select_values.empty?

      selected = selected_column_names(records)
      return names if selected.include?('*')

      names.reject do |name|
        association = projected_resource.reflect_on_association(name)
        next false if association.nil?

        missing = preload_owner_keys(association).reject { |key| selected.include?(key.to_s) }
        next false if missing.empty?

        warn_unselected_preload_key(name, missing)
        true
      end
    end

    # Only a plain column reference can be read back off a select.
    PLAIN_SELECT_REFERENCE = /\A(?:"?(?<table>\w+)"?\.)?"?(?<column>\w+|\*)"?\z/

    def selected_column_names(records)
      table = projected_resource.table_name

      records.select_values.each_with_object(Set.new) do |value, names|
        select_references(value).each do |reference|
          match = PLAIN_SELECT_REFERENCE.match(reference)
          next if match.nil? || (match[:table] && match[:table] != table)

          names << match[:column]
        end
      end
    end

    # One select_value can name several columns, which splitting on commas recovers — but only
    # while no parenthesis is in play: `COALESCE(uri, driver_id, name) AS x` would otherwise read
    # as naming driver_id, and the preload that lets through raises on a column the row does not
    # carry, which is the failure this guard exists to prevent. An expression names nothing here,
    # so the preload is skipped and the relation left to the lazy load — the safe way to be wrong.
    #
    # SqlLiteral is a String, and is meant to be read like one. An Arel attribute is not, and
    # carries its table and column apart, `products.*` included.
    def select_references(value)
      case value
      when String, Symbol
        text = value.to_s
        text.include?('(') ? [] : text.split(',').map(&:strip)
      when Arel::Attributes::Attribute
        value.relation.respond_to?(:name) ? ["#{value.relation.name}.#{value.name}"] : []
      else
        []
      end
    end

    # Re-checks the preloads a relation already carries, for the callers that attach them before
    # the select is final — HasManyGetter builds its query in prepare_query and only projects in
    # #perform. Judging the intermediate select drops preloads apply_projection was about to make
    # safe: inherited_load_columns reads preload_values and selects their keys precisely because
    # they are already attached. So the question is asked here, where the select is the one the
    # query will run, and #preload only ever adds — removing one means rebuilding the relation.
    def drop_unselected_preloads(records)
      values = records.preload_values
      return records if values.empty?

      kept_names = selectable_preloads(records, association_names(values))
      kept = values.select do |value|
        names = value.is_a?(Hash) ? value.keys : [value]
        names.all? { |name| kept_names.include?(name.to_sym) }
      end

      kept.size == values.size ? records : records.except(:preload).preload(kept)
    end

    def warn_unselected_preload_key(association_name, missing_keys)
      reason = "its \"#{missing_keys.join('", "')}\" key is not in the query's select"
      return unless PRELOAD_SKIPS_WARNED.add?([@collection&.name, association_name, reason])

      FOREST_LOGGER.warn "The \"#{association_name}\" relation of the \"#{@collection&.name}\" " \
        "collection cannot be preloaded (#{reason}) — it falls back to the lazy load, which reads " \
        'it once per record where that key is on the row and resolves to a null relation where ' \
        'it is not.'
    end

    # records_by_owner's keys are the exact objects the Preloader was given, not copies — no need
    # to re-find them by id, which would also mis-assign on a nil or duplicate id (composite
    # primary keys are supported elsewhere in this gem).
    def assign_preloaded_targets(association_name, records_by_owner)
      records_by_owner.each do |record, target|
        record.define_singleton_method(association_name) { target.first }
      end
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
      records = records.references(eager_loads) if eager_loads.any?
      select = (compute_select_fields(eager_loads) + inherited_load_columns(records, eager_loads)).uniq

      # NOTICE: The _forest_admin_eager_load marker heading the select is only stripped by the
      #         JoinDependency override, which runs when the query really eager loads; it would
      #         otherwise reach the SQL as a column name.
      records.eager_loading? ? records.select(*select) : records.select(*select.drop(1))
    end

    # What the query loads on its own, outside the projection: a relation a filter or a scope
    # joined, or one an association scope or default_scope includes/preloads. Joined, its record is
    # built off the JOIN and needs its columns in the select; preloaded, the preloader reads its
    # key off this row and raises at query time, out of MissingAttributeValve's reach, without it.
    def inherited_load_columns(records, projected)
      joined = association_names(records.eager_load_values)
      preloaded = association_names(records.preload_values)
      if records.eager_loading?
        joined += association_names(records.includes_values)
      else
        preloaded += association_names(records.includes_values)
      end
      projected = projected.map(&:to_sym)

      columns = (joined - projected).uniq.flat_map do |name|
        association = projected_resource.reflect_on_association(name)
        next [] if association.nil? || SchemaUtils.polymorphic?(association)

        association.klass.column_names.map { |column| "#{association.table_name}.#{column}" }
      end

      (preloaded - joined - projected).uniq.each do |name|
        association = projected_resource.reflect_on_association(name)
        next if association.nil?

        keys = preload_owner_keys(association)
        keys += [association.foreign_type] if SchemaUtils.polymorphic?(association)
        keys.each { |key| columns << "#{projected_resource.table_name}.#{key}" if column?(projected_resource, key) }
      end

      columns
    end

    def association_names(values)
      values.flat_map { |value| value.is_a?(Hash) ? value.keys : value }.map(&:to_sym)
    end

    # count may never have run #perform on this instance (it builds its own getter and calls
    # #count directly) — falls back to @records, the filtered-but-unprojected query prepare_query
    # already built, so a narrowed multi-column select is never handed to COUNT.
    def unprojected_records
      @unprojected_records || @records
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

      # An STI model needs its own type column projected regardless of what's requested: without
      # it, .becomes(subclass) later has nothing to key off, and every row loads as the base class.
      if column?(projected_resource, projected_resource.inheritance_column)
        select << "#{projected_resource.table_name}.#{projected_resource.inheritance_column}"
      end

      # Include columns used in default ordering for batch cursor compatibility
      if projected_resource.respond_to?(:default_scoped) && projected_resource.default_scoped.order_values.any?
        projected_resource.default_scoped.order_values.each do |order_value|
          if order_value.is_a?(Arel::Nodes::Ordering)
            # Extract column name from Arel node
            column_name = order_value.expr.name if order_value.expr.respond_to?(:name)
            select << "#{projected_resource.table_name}.#{column_name}" if column?(projected_resource, column_name)
          elsif order_value.is_a?(String) || order_value.is_a?(Symbol)
            # NOTICE: Only a bare column name can be table-qualified. An ordering expression such
            #         as "LOWER(name) ASC" is left out: qualifying it would reach the SQL as
            #         table.LOWER(name).
            column_name = order_value.to_s.split(' ').first.split('.').last
            select << "#{projected_resource.table_name}.#{column_name}" if column?(projected_resource, column_name)
          end
        end
      end

      # Handle ActiveStorage associations from both @includes and @field_names_requested
      active_storage_associations_processed = Set.new

      (@includes + @field_names_requested).each do |path|
        association = path.is_a?(Symbol) ? projected_resource.reflect_on_association(path) : get_one_association(path)
        next unless association
        next if active_storage_associations_processed.include?(association.name)
        # NOTICE: Same rule as every other relation below — a relation the query does not join is
        #         read by a SELECT of its own, and naming its table here would leave it out of the
        #         FROM clause. The relationships route preloads its display-only relations.
        next unless is_active_storage_association?(association) && joined?(association, joined_relations)

        # Include all columns from ActiveStorage tables to avoid initialization errors
        table_name = association.table_name
        association.klass.column_names.each do |column_name|
          select << "#{table_name}.#{column_name}"
        end

        # Include the foreign key linking the attachment to its owner
        select_foreign_keys(select, projected_resource, association, joined?(association, joined_relations))

        active_storage_associations_processed.add(association.name)
      end

      # preload_polymorphic_associations reads a polymorphic association's own foreign_type
      # internally to resolve its target class, whether or not that association was itself
      # requested as a projected field — @includes already carries every one it might preload
      # (searchExtended widens it beyond @field_names_requested for exactly this reason), so this
      # runs over @includes rather than only the requested subset the loop below covers.
      @includes.each do |path|
        association = path.is_a?(Symbol) ? projected_resource.reflect_on_association(path) : get_one_association(path)
        next unless association && SchemaUtils.polymorphic?(association)

        select << "#{projected_resource.table_name}.#{association.foreign_type}"
        select_foreign_keys(select, projected_resource, association, joined?(association, joined_relations))
      end

      # A cross-database to-one relation is never joined, so select_foreign_keys names nothing
      # owner-side for the has_one half of it — and the preloader reads that key off this row.
      # Without it here the guard in preload_cross_database_associations fires on every page and
      # the relation keeps being read once per record, which is the N+1 this file removes. Off
      # @includes for the same reason as the polymorphic loop above: the preload runs over all of
      # it, not only the requested subset.
      cross_database_associations(projected_resource).each do |name|
        association = projected_resource.reflect_on_association(name)
        preload_owner_keys(association).each do |key|
          select << "#{projected_resource.table_name}.#{key}" if column?(projected_resource, key)
        end
      end

      @field_names_requested.each do |path|
        association = get_one_association(path)
        if association
          through_chain = []
          current_association = association
          # The raw reflection, not get_one_association: a through hop legitimately points at a
          # model kept out of the schema (a join table is the usual one), which get_one_association
          # filters out — leaving the walk on nil and failing the whole list rather than the one
          # field. The chain below already reads its own hops off reflect_on_association.
          while current_association && current_association.options[:through]
            through_chain << current_association.options[:through]
            current_association = projected_resource.reflect_on_association(current_association.options[:through])
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

                  select_foreign_keys(select, current_resource, direct_assoc) if direct_assoc
                else
                  # Direct association (not nested through)
                  select_foreign_keys(select, current_resource, through_assoc)
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

            select_foreign_keys(select, projected_resource, association, joined?(association, joined_relations))
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
            elsif column?(association.klass, association_path)
              select << "#{table_name}.#{association_path}"
            end
          end
        else
          # Only add as column if it's not an association
          # Associations are handled by the through chain logic above
          #
          # NOTICE: Only a real column reaches the select. A name the collection does not hold is
          #         dropped, exactly as the serializer already drops it — reaching the SQL it
          #         would raise, and since the Forest-Projection header feeds this it would carry
          #         whatever text the caller wrote into the select list.
          unless association
            select << "#{projected_resource.table_name}.#{path}" if column?(projected_resource, path)
          end
        end
      end

      # A requested Smart Field's own declared columns — never its relation paths, which name a
      # relation smart_field_preloads loads by a query of its own rather than a column this select
      # could name. project? already refused this whole projection if a requested-but-undeclared
      # one is among @field_names_requested, so this loop only ever sees fields that do declare.
      @collection.smart_field_dependency_columns(@field_names_requested).each do |column_name|
        select << "#{projected_resource.table_name}.#{column_name}" if column?(projected_resource, column_name)
      end

      # smart_field_preloads loads a relation path out of this query, but the key preload reads
      # off this row still has to be selected here, or it raises a missing-attribute error on the
      # whole list rather than on the one field — at query-resolution time, out of reach of
      # MissingAttributeValve, which only ever runs during serialization.
      #
      # Driven off the same field set as the preload, and off the raw reflection rather than
      # get_one_association: the latter drops an association whose target model is excluded from
      # the schema (QueryHelper filters on model_included?), which would leave exactly such a
      # relation preloaded with no key to preload it by.
      @collection.smart_field_dependency_relation_paths(serialized_smart_field_names).each do |relation_path|
        association = projected_resource.reflect_on_association(relation_path.relations.first.to_sym)
        next unless association

        select_dependency_preload_keys(select, relation_path, joined_relations)
        select_foreign_keys(select, projected_resource, association, joined?(association, joined_relations))

        # A relation the caller also projects is built off the JOIN, and the preloader leaves an
        # already-loaded association alone — the declared column has to ride along in this select.
        next unless relation_path.relations.size == 1 && joined_relations&.include?(association.name)
        next if SchemaUtils.polymorphic?(association) || !column?(association.klass, relation_path.column)

        select << "#{association.table_name}.#{relation_path.column}"
      end

      select.uniq
    end

    def column?(model, name)
      !name.nil? && model.column_names.include?(name.to_s)
    end

    def joined?(association, joined_relations)
      joined_relations.nil? || joined_relations.include?(association.name)
    end

    # NOTICE: A belongs_to carries its foreign key on the owner row, a has_one on the target row.
    #         Qualifying a has_one key with the owner table names a column that does not exist,
    #         and the target table only reaches the FROM clause when the query joins it — a
    #         preloaded relation is read by a SELECT of its own and needs nothing here, the
    #         owner primary key already being selected.
    def select_foreign_keys(select, owner, association, joined = true)
      if association.macro == :belongs_to
        Array(association.foreign_key).each { |fk| select << "#{owner.table_name}.#{fk}" }
      elsif association.macro == :has_one && joined
        Array(association.foreign_key).each { |fk| select << "#{association.table_name}.#{fk}" }
      end
    end

    # The columns preload reads off an owner row to key the association it is about to load.
    #
    # join_foreign_key is that key: the foreign key for a belongs_to, active_record_primary_key —
    # so options[:primary_key] when one is declared, the real primary key only by default — for
    # everything else. A :through reflection answers its *source*'s key instead, which is no
    # column of the owner table at all: what the preloader reads there is the key of the hop it
    # starts with, so the chain is walked down to that first hop before asking.
    #
    # Getting this wrong does not cost the one field — it raises resolving the query, where
    # MissingAttributeValve (a serialization-time valve) never sees it, and takes down the list.
    def preload_owner_keys(association)
      reflection = association
      reflection = reflection.through_reflection while reflection.through_reflection?

      Array(reflection.join_foreign_key)
    end

    # The same keys, but for every hop of a declared path this select can still reach, not only
    # the first. The first hop reads the root row, which this select builds. The hop after it
    # reads the rows that first hop produced — and when that hop is a relation the query *joins*,
    # those rows are the narrowed ones built off the JOIN, so its key has to be named here too.
    # It was not, and the list answered 500 rather than the one field (PRD-1316).
    def select_dependency_preload_keys(select, relation_path, joined_relations)
      chains = flatten_dependency_hops(relation_path.relations)
      return if chains.empty?

      narrowed_hops(chains, joined_relations).each do |owner, reflection|
        Array(reflection.join_foreign_key).each do |key|
          select << "#{owner.table_name}.#{key}" if column?(owner, key)
        end
      end
    end

    # The leading hops whose owner row this query builds itself, narrowed, and whose key it
    # therefore has to name.
    #
    # The first hop always counts: it reads the root row. One hop past a *joined* relation counts
    # too, its owners being the narrowed rows the JOIN built rather than the whole ones a preload
    # selects. Two relations can be the joined one, and either shape reaches here:
    #   - the chain's own first hop, which for a :through is the relation it goes through
    #     (`island` of `has_one :location, through: :island`): the preloader reuses the loaded
    #     association and reads the source key off it;
    #   - the first declared relation, when the request displays it: the preloader then leaves
    #     that whole declaration alone, and the next declared relation reads its key off the
    #     joined rows. For a plain relation both are the same hop; for a :through they are not,
    #     and the second was missed.
    #
    # Nothing past those: joined_relations only ever names root relations, so every later hop
    # comes from a preload of its own, which selects whole rows. Every table named up to here is
    # in the FROM clause — eager loading a :through joins the tables it goes through as well.
    def narrowed_hops(chains, joined_relations)
      declared, head = chains.first
      hops = chains.flat_map(&:last)

      count = joined?(head.first.last, joined_relations) ? 2 : 1
      count = [count, head.size + 1].max if joined?(declared, joined_relations)

      hops.first(count)
    end

    # The direct reflections the preloader really walks for a declared path, grouped by the
    # relation that declared them and each paired with the model it reads its key off.
    #
    # A :through hop is not preloaded as one: Preloader::ThroughAssociation loads the through
    # relation, then the source relation on those records. So the relation a path names can hide
    # the one the query joins — `location:coordinates` walking Tree's `has_one :location, through:
    # :island` really starts on the joined `island`, which the declaration never mentions.
    def flatten_dependency_hops(relations)
      model = projected_resource

      relations.map do |name|
        association = model.reflect_on_association(name.to_sym)
        return [] if association.nil? || SchemaUtils.polymorphic?(association)

        chain = [association, flatten_through_hops(model, association)]
        model = association.klass
        chain
      end
    # Same net as preload_skip_reason's, for the same shapes: a :through naming a hop that does
    # not exist, or a class_name pointing at no model, answers NameError off #klass. Nothing is
    # selected for such a path — skip_preload? drops it from the preload too, so there is no key
    # left to select for.
    rescue NameError, ActiveRecord::ActiveRecordError
      []
    end

    def flatten_through_hops(owner, association)
      return [[owner, association]] unless association.through_reflection?

      flatten_through_hops(owner, association.through_reflection) +
        flatten_through_hops(association.through_reflection.klass, association.source_reflection)
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
