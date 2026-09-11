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
      # Two different contributors, kept apart rather than folded into one flag: a lambda that
      # runs without raising isn't necessarily a lambda that filtered anything (one returning its
      # query untouched pushes no condition, constrains nothing). Conflating the two let a
      # malformed-UUID search past a no-op lambda serve the whole table. @conditions_pushed alone
      # already proves a real constraint (not necessarily a matching row — a LIKE that matches
      # nothing still pushed a condition, and still correctly answers none); malformed_uuid_search?
      # only ever needs weighing against @lambda_contributed, since every LIKE-scan branch below
      # already excludes itself on it and so can never be the reason @conditions_pushed is true.
      @conditions_pushed = false
      @lambda_contributed = false
      @records = search_param

      caller_filter = @params[:filters].present? ? ForestLiana::ScopeManager.inject_context_variables(@params[:filters], @user) : nil
      # A bare recorded path is by construction a root column (never a caller-named field), so it's
      # dropped here rather than resolved: FieldPath would otherwise treat a root column whose name
      # collides with an association name (e.g. a `location` column alongside a `location`
      # association) as a traversal into that association, checking the wrong collection. This
      # also means every root-column path push_condition records above is never itself checked —
      # root_model is already pinned readable, so that's the intended effect, not a gap.
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
        # A smart-field `search:` lambda can read anything — by construction, its reach is outside
        # the footprint assert_can_read_query_fields checks above, in both plain and extended
        # search. Deliberately never refused: the lambda runs identically regardless of
        # `searchExtended`, so gating a refusal on that param would only cost every customer of
        # this documented hook their extended search, without closing anything a caller couldn't
        # already reach on the default path.
        ForestLiana.schema_for_resource(@resource).fields.each do |field|
          if field.try(:[], :search)
            begin
              @records = field[:search].call(@records, @search)
              @lambda_contributed = true
              (@fields_searched << field[:field].to_s) if field[:type] == 'String'
            rescue => exception
              FOREST_REPORTER.report exception
              FOREST_LOGGER.error "Cannot search properly on Smart Field:\n" \
                "#{exception}"
              # Nothing else: a failed lambda simply doesn't count as a contributor, rather than
              # emptying @records here — a later field's own lambda (or the columns search_param
              # already matched) must still be free to serve the request.
            end
          end
        end

        # A real condition (id/enum/tag/column match) is served regardless of malformed_uuid_search?
        # — it never suppressed those branches, only the LIKE scans. A lambda's own contribution is
        # weighed against it instead: a malformed-UUID-shaped search is still emptied if all that
        # "constrained" it was a lambda, the same guarantee the base gave before a lambda could run
        # at all. Neither contributor at all is the one case left to fall through to the whole table.
        #
        # A known cost of that guarantee: a lambda that genuinely narrows the query (not just one
        # that runs without raising) still loses to a malformed-UUID-shaped term, exactly as if it
        # hadn't run at all — this can't currently tell "ran and did nothing" apart from "ran and
        # found real rows". Logged rather than silently discarded, since nothing else would ever
        # surface it to whoever built the smart-search hook.
        if @lambda_contributed && !@conditions_pushed && malformed_uuid_search?
          FOREST_LOGGER.info "A smart-search lambda's result on the \"#{ForestLiana.name_for(root_model)}\" " \
            "collection was discarded: the search term (#{@search.inspect}) is UUID-shaped but " \
            'invalid, and no other condition constrained the query.'
        end
        @records = @records.none unless @conditions_pushed || (@lambda_contributed && !malformed_uuid_search?)
      end

      @records = sort_query
      @records
    end

    def format_column_name(table_name, column_name)
      ForestLiana::AdapterHelper.format_column_name(table_name, column_name)
    end

    # A subquery, not an executed id list: `.map` would run `tagged_records` (a JOIN through
    # taggings/tags) right here, before assert_can_read_query_fields ever runs in #perform below —
    # `.to_sql` defers it to whenever the outer query actually executes, same as every other
    # condition this method builds. A subquery matching nothing still emits valid SQL yielding zero
    # rows (never the SQL-invalid `IN ()`), and is OR'd alongside the other conditions — no
    # behavior change for a search that tags nothing.
    def acts_as_taggable_query(tagged_records)
      # Qualified with the resource's own table on both sides: unqualified, this SELECTs (and
      # compares against) an ambiguous "id" once the join through taggings (which has its own "id"
      # primary key) is added to the subquery. `reselect`, not `select`: some acts_as_taggable_on
      # query builders already select their own columns (`tagged_records` already carries a SELECT,
      # not just a WHERE) — `select` would append to that, not replace it, leaving a multi-column
      # subquery an `IN` can't use.
      qualified_pk = "#{@resource.table_name}.#{@resource.primary_key}"
      "#{qualified_pk} IN (#{tagged_records.reselect(qualified_pk).to_sql})"
    end

    def search_param
      @search_field_paths = []

      if @search
        conditions = []
        # Kept apart from +conditions+: a tag name can itself contain a colon (":search_value...
        # is exactly that shape), and the final `where(sql, binds)` call scans the WHOLE string
        # for a `:word` pattern to substitute — one living inside this subquery's own already-quoted
        # SQL text would either raise "missing value for :whatever" or, worse, silently swallow a
        # legitimate bind if the tag name happened to collide with one of ours.
        tag_conditions = []

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
        # The path recorded here is the root primary key, not the taggings/tags tables the query
        # actually joins — those aren't a Forest relation this class knows how to name, so this
        # search contributes no footprint for them (rarely a live gap in practice, since those
        # tables are rarely exposed as Forest collections themselves). push_condition below always
        # receives a non-nil string, so @conditions_pushed is unconditionally true for any taggable
        # resource regardless of whether the term actually matched a tag — harmless (a non-matching
        # subquery still yields zero rows) but distinct from every other branch's meaning of the flag.
        if @resource.try(:taggable?) && @resource.respond_to?(:acts_as_taggable)
          @resource.acts_as_taggable.each do |field|
            tagged_records = @records.tagged_with(@search.downcase)
            push_condition(tag_conditions, acts_as_taggable_query(tagged_records), @resource.primary_key.to_s)
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

        unless conditions.empty? && tag_conditions.empty?
          # The two arrays never share a `where` call: substituting binds into +conditions+ here,
          # before joining in +tag_conditions+, is what keeps a tag name's own colon out of the
          # bind-scanning pass below — by the time they're joined, there's nothing left to scan for.
          bound = unless conditions.empty?
            root_model.sanitize_sql_array([
              conditions.join(' OR '),
              search_value_for_string: "%#{@search.downcase}%",
              search_value_for_uuid: @search.to_s
            ])
          end

          @records = @resource.where([bound, *tag_conditions].compact.join(' OR '))
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
      @conditions_pushed = true
      conditions << condition
    end

    def extended_search?
      @params['searchExtended'].to_i == 1
    end
  end
end
