module ForestLiana
  class SearchQueryBuilder
    include ForestLiana::Ability::Permission

    REGEX_UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    attr_reader :fields_searched, :search_field_paths

    def initialize(params, includes, collection, user)
      @params = params
      @includes = includes
      @collection = collection
      @fields_searched = []
      # '' is truthy, so without .presence an empty search still builds LIKE '%%' predicates.
      @search = @params[:search].presence
      @user = user
    end

    def perform(resource)
      @resource = @records = resource
      @tables_associated_to_relations_name =
        ForestLiana::QueryHelper.get_tables_associated_to_relations_name(@resource)
      assert_extended_search_describable!
      @records = search_param

      caller_filter = @params[:filters].present? ? ForestLiana::ScopeManager.inject_context_variables(@params[:filters], @user) : nil
      # A bare recorded path is by construction a root column (never a caller-named field), so it's
      # dropped here rather than resolved: FieldPath would otherwise treat a root column whose name
      # collides with an association name (e.g. a `location` column alongside a `location`
      # association) as a traversal into that association, checking the wrong collection.
      assert_can_read_query_fields(
        @user,
        root_model,
        filter_paths: FiltersParser.field_paths(caller_filter),
        search_paths: @search_field_paths.select { |path| path.include?(':') },
      )
      filters = ForestLiana::ScopeManager.append_scope(caller_filter, @user, @collection.name)

      unless filters.blank?
        @records = FiltersParser.new(filters, @records, @params[:timezone]).apply_filters
      end

      if @search
        ForestLiana.schema_for_resource(@resource).fields.each do |field|
          if field.try(:[], :search)
            begin
              @records = field[:search].call(@records, @search)
              (@fields_searched << field[:field].to_s) if field[:type] == 'String'
            rescue => exception
              FOREST_REPORTER.report exception
              FOREST_LOGGER.error "Cannot search properly on Smart Field:\n" \
                "#{exception}"
              # A failed lambda is the same "cannot be evaluated" case as no column matching at
              # all: answering no records keeps the guarantee this file makes elsewhere, that a
              # search that cannot be resolved never falls through to the unfiltered table.
              @records = @records.none
            end
          end
        end
      end
      @records = sort_query
      @records
    end

    def format_column_name(table_name, column_name)
      ForestLiana::AdapterHelper.format_column_name(table_name, column_name)
    end

    def acts_as_taggable_query(tagged_records)
      ids = tagged_records
        .map {|t| t[@resource.primary_key]}
        .join(',')

      if ids.present?
        return "#{@resource.primary_key} IN (#{ids})"
      end
    end

    def search_param
      @search_field_paths = []

      if @search
        conditions = []

        @resource.columns.each_with_index do |column, index|
          @fields_searched << column.name if text_type?(column.type) || column.type == :uuid
          column_name = format_column_name(@resource.table_name, column.name)
          if (@collection.search_fields && !@collection.search_fields.include?(column.name))
            conditions
          elsif column.name == 'id'
            if column.type == :integer
              value = @search.to_i
              push_condition(conditions, "#{@resource.table_name}.id = #{value}", column.name) if value > 0
            elsif REGEX_UUID.match(@search)
              push_condition(conditions, "#{@resource.table_name}.id = :search_value_for_uuid", column.name)
            end
          # NOTICE: Rails 3 do not have a defined_enums method
          elsif REGEX_UUID.match(@search) && column.type == :uuid
            if column.respond_to?(:array) && column.array
              push_condition(conditions, ":search_value_for_uuid = ANY(#{column_name})", column.name)
            else
              push_condition(conditions, "#{column_name}  = :search_value_for_uuid", column.name)
            end
          elsif @resource.respond_to?(:defined_enums) &&
            @resource.defined_enums.has_key?(column.name) &&
            !@resource.defined_enums[column.name][@search.downcase].nil?
            push_condition(conditions, "#{column_name} =
              #{@resource.defined_enums[column.name][@search.downcase]}", column.name)
          elsif !(column.respond_to?(:array) && column.array) && text_type?(column.type) && !malformed_uuid_search?
            push_condition(conditions, "LOWER(#{column_name}) LIKE :search_value_for_string", column.name)
          end
        end

        # ActsAsTaggable
        # Root-owned by construction: `condition` below both gates the `push_condition` call and
        # is the exact string it pushes, so the recorded path and the SQL can't diverge. Not
        # covered by a live spec — acts_as_taggable_on isn't installed in the dummy app, and
        # stubbing `taggable?`/`acts_as_taggable` on the real Tree model to simulate it permanently
        # corrupts ActiveRecord::Delegation's per-class method cache for the rest of the process,
        # regardless of the stubbing method used.
        if @resource.try(:taggable?) && @resource.respond_to?(:acts_as_taggable)
          @resource.acts_as_taggable.each do |field|
            tagged_records = @records.tagged_with(@search.downcase)
            condition = acts_as_taggable_query(tagged_records)
            push_condition(conditions, condition, @resource.primary_key.to_s) if condition
          end
        end

        if extended_search?
          ForestLiana::QueryHelper.get_one_association_names_symbol(@resource).each do |association|
            if @collection.search_fields
              association_search = @collection.search_fields.map do |field|
                if field.include?('.') && field.split('.')[0] == association.to_s
                  field.split('.')[1]
                end
              end
              association_search = association_search.compact
            end

            if @includes.include? association.to_sym
              resource = @resource.reflect_on_association(association.to_sym)
              unless (SchemaUtils.polymorphic?(resource))
                resource.klass.columns.each do |column|
                  if !(column.respond_to?(:array) && column.array) && text_type?(column.type) && !malformed_uuid_search?
                    if @collection.search_fields.nil? || (association_search &&
                      association_search.include?(column.name))
                      push_condition(conditions, association_search_condition(resource.table_name,
                        column.name), "#{association}:#{column.name}")
                    end
                  end
                end
              end
            end
          end

          if @collection.search_fields
            # Unlike QueryHelper.get_one_associations, SchemaUtils.many_associations does not
            # filter out a target the agent doesn't expose — an association named by search_fields
            # but pointing at such a model would otherwise be searched, then reported as an
            # "unexposed" path nobody could ever have granted read on.
            SchemaUtils.many_associations(@resource)
              .select { |reflection| SchemaUtils.model_included?(reflection.klass) }
              .map(&:name).each do
              |association|
              association_search = @collection.search_fields.map do |field|
                if field.include?('.') && field.split('.')[0] == association.to_s
                  field.split('.')[1]
                end
              end
              association_search = association_search.compact
              unless association_search.empty?
                resource = @resource.reflect_on_association(association.to_sym)
                resource.klass.columns.each do |column|
                  if !(column.respond_to?(:array) && column.array) && text_type?(column.type) && !malformed_uuid_search?
                    if association_search.include?(column.name)
                      push_condition(conditions, association_search_condition(resource.table_name,
                        column.name), "#{association}:#{column.name}")
                    end
                  end
                end
              end
            end
          end
        end

        if conditions.empty?
          # NOTICE: a malformed-UUID search suppresses the only conditions it could
          #         have produced (text LIKE scans); match nothing rather than fall
          #         through to an unfiltered query that returns the whole table. A declared
          #         smart-search lambda is the one exception: it ORs its own conditions in right
          #         after this, so a collection whose only search surface is that lambda is left
          #         unfiltered here rather than pre-emptied to none.
          @records = @resource.none if malformed_uuid_search? || !smart_search_declared?
        else
          @records = @resource.where(
            conditions.join(' OR '),
            search_value_for_string: "%#{@search.downcase}%",
            search_value_for_uuid: @search.to_s
          )
        end
      end

      @records
    end

    def association_table_name(name)
      QueryHelper.get_tables_associated_to_relations_name(@records).detect { |key, values|
        break key if Array(values).include?(name)
      }

    end

    # Recorded here, checked separately by +assert_sort_readable!+: a count route runs this same
    # parsing (Rails strips the ORDER BY from the emitted COUNT SQL on its own) but must not refuse
    # a sort it never actually applies, so the two are split rather than checked inline.
    def sort_query
      @sort_field_paths = []

      if @params[:sort]
        @params[:sort].split(',').each do |field|
          order_detected = detect_sort_order(field)
          order = order_detected.upcase
          field.slice!(0) if order_detected == :desc

          @sort_field_paths << sort_field_path(field)

          field = detect_reference(field)
          if field.index('.').nil?
            column = ForestLiana::AdapterHelper.format_column_name(@resource.table_name, field)
          else
            column = field
          end

          @records = @records.order(Arel.sql("#{column} #{order}"))
        end
      end

      @records
    end

    def detect_reference(param)
      ref, field = param.split('.')

      if ref && field
        association = @resource.reflect_on_all_associations
          .find {|a| a.name == ref.to_sym }

        referenced_table = association ? association_table_name(association.name) : ref

        ForestLiana::AdapterHelper
          .format_column_name(referenced_table, field)
      else
        param
      end
    end

    def detect_sort_order(field)
      return (if field[0] == '-' then :desc else :asc end)
    end

    def assert_sort_readable!(user, root_model)
      assert_can_read_query_fields(user, root_model, sort_paths: @sort_field_paths || [])
    end

    def association_search_condition table_name, column_name
      column_name = format_column_name(table_name, column_name)
      "LOWER(#{column_name}) LIKE :search_value_for_string"
    end

    def acts_as_taggable?(field)
      @resource.try(:taggable?) && @resource.respond_to?(:acts_as_taggable) &&
        @resource.acts_as_taggable.include?(field)
    end

    private

    def text_type?(type_sym)
      [:string, :text, :citext].include? type_sym
    end

    # NOTICE: A search that is UUID-shaped but fails the strict REGEX_UUID (a
    #         truncated or mistyped UUID) can never match a real UUID column and,
    #         on text columns, only triggers `LOWER(col) LIKE '%…%'` sequential
    #         scans that can hit the statement timeout. Valid UUIDs are excluded
    #         so they keep matching UUIDs stored in varchar/text columns.
    def malformed_uuid_search?
      return false unless @search.is_a?(String)

      @search.match?(/\A[0-9a-f]+-[0-9a-f]+-[0-9a-f]+-[0-9a-f]+-[0-9a-f]+\z/i) &&
        !REGEX_UUID.match?(@search)
    end

    # Mirrors detect_reference's own `ref, field = param.split('.')` destructuring: a path deeper
    # than one relation silently drops everything past the second segment there, so the same
    # truncation is checked here — checking more than what actually reaches the query would refuse
    # a request the extra segments never touch.
    def sort_field_path(field)
      head, dot, tail = field.partition('.')

      dot.empty? ? head : "#{head}:#{tail.split('.').first}"
    end

    # `@resource` is either the model class (ResourcesGetter) or an already-scoped
    # Relation/CollectionProxy (HasManyGetter) — FieldPath needs the class either way.
    def root_model
      @resource.respond_to?(:klass) ? @resource.klass : @resource
    end

    # The single site every search condition is added at, so the footprint reported to the
    # permission guard can never drift from what the generated SQL actually reads.
    def push_condition(conditions, condition, path)
      return unless condition

      @search_field_paths << path
      conditions << condition
    end

    def extended_search?
      @params['searchExtended'].to_i == 1
    end

    def smart_search_declared?
      ForestLiana.schema_for_resource(root_model)&.fields&.any? { |field| field.try(:[], :search) }
    end

    # A smart-field search lambda can read anything, so an extended search on a collection that
    # declares one has no footprint to check against permissions — refused before anything runs,
    # rather than left to compare a partial footprint. A plain search on the same collection is
    # unaffected: what it reads besides the lambda is root-only and pinned readable, so nothing
    # checkable is skipped by serving it.
    def assert_extended_search_describable!
      return unless @search && extended_search? && smart_search_declared? && has_permission_system?

      raise ForestLiana::Ability::Exceptions::UndescribableSearchError.new(ForestLiana.name_for(root_model))
    end
  end
end
