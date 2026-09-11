module ForestLiana
  describe SearchQueryBuilder do
    let(:user) { { 'id' => '1', 'rendering_id' => 1 } }
    let(:collection) { ForestLiana::Model::Collection.new(name: 'Tree', fields: []) }
    let(:search_uuid) { '75fbcb43-f6f8-4cd1-861f-09a61fd1ddad' }
    let(:params) { { search: search_uuid, searchExtended: '0' } }
    let(:builder) { described_class.new(params, [], collection, user) }

    before do
      allow(ForestLiana::ScopeManager)
        .to receive(:append_scope)
        .and_return(nil)
      allow(ForestLiana)
        .to receive(:schema_for_resource)
        .and_return(ForestLiana::Model::Collection.new(name: 'Tree', fields: []))
    end

    # acts_as_taggable_on isn't installed in the dummy app (see the comment on search_param's
    # ActsAsTaggable block), so exercised directly against a plain relation standing in for
    # `tagged_records` rather than through a real taggable model.
    describe '#acts_as_taggable_query' do
      # Only #perform sets @resource (root_model in particular is used by both the columns loop
      # and this method) — a nil search short-circuits search_param's own column loop, establishing
      # it without exercising the rest of search_param.
      let(:params) { { search: nil } }

      before { builder.perform(Tree.all) }

      it 'produces a single-column, table-qualified subquery even when the relation already selects columns of its own' do
        tagged_records = Tree.where(name: 'Oak').select('trees.*')

        sql = builder.acts_as_taggable_query(tagged_records)

        expect(sql).to eq(%(trees.id IN (SELECT "trees"."id" FROM "trees" WHERE "trees"."name" = 'Oak')))
      end

      # The regression this guards against: a single-String `where` never scans for a bind
      # placeholder, but `where(sql, binds_hash)` does, over the WHOLE string — including a tag
      # name's own already-quoted SQL text once joined into it. search_param avoids that by
      # substituting binds into its own conditions before ever joining the tag condition in;
      # joining first (the bug) reintroduces exactly this crash.
      it 'stays safe joined into a bind-substituted string, but would crash joined before substitution' do
        tag_sql = builder.acts_as_taggable_query(Tree.where(name: 'foo:bar'))
        column_condition = 'LOWER("trees"."name") LIKE :search_value_for_string'

        bound = Tree.sanitize_sql_array([column_condition, search_value_for_string: '%x%'])
        expect { Tree.where([bound, tag_sql].join(' OR ')).to_sql }.not_to raise_error

        expect { Tree.where("#{column_condition} OR #{tag_sql}", search_value_for_string: '%x%').to_sql }
          .to raise_error(ActiveRecord::PreparedStatementInvalid)
      end
    end

    describe '#perform' do
      context 'when the search is a malformed UUID' do
        # UUID-shaped but fails the strict REGEX_UUID (mistyped/truncated group).
        # Starts with a letter so #to_i is 0 and adds no integer-`id` condition,
        # leaving the text LIKE scans as the only possible matches.
        let(:params) { { search: 'abcdef12-3456-4ae-ad4f-5662757713a2', searchExtended: '0' } }

        before do
          Tree.create!(name: 'Oak')
          Tree.create!(name: 'Elm')
        end

        after { Tree.destroy_all }

        it 'matches nothing instead of returning the unfiltered table' do
          expect(builder.perform(Tree.all).count).to eq(0)
        end
      end

      context 'when the malformed UUID also happens to match a real id' do
        # Starts with digits, so #to_i produces a real integer-id condition alongside the
        # suppressed LIKE scans — malformed_uuid_search? only ever suppressed the latter, so this
        # match must still be served, not discarded by the search being UUID-shaped.
        let(:params) { { search: "#{tree.id.to_s.rjust(8, '0')}-1234-9abc-1234-1234567890ab", searchExtended: '0' } }
        let!(:tree) { Tree.create!(name: 'Oak') }

        after { Tree.destroy_all }

        it 'still serves the id match' do
          expect(builder.perform(Tree.all).pluck(:id)).to eq([tree.id])
        end
      end

      context 'when searchExtended is on and the search is a malformed UUID' do
        # HashWithIndifferentAccess: the code reads @params['searchExtended'] (string).
        let(:params) do
          ActiveSupport::HashWithIndifferentAccess.new(
            search: 'abcdef12-3456-4ae-ad4f-5662757713a2', searchExtended: '1'
          )
        end
        let(:builder) { described_class.new(params, [:owner], collection, user) }

        before { Tree.create!(name: 'Oak') }

        after { Tree.destroy_all }

        it 'does not build LIKE scans on associated text columns either' do
          expect(builder.perform(Tree.all).to_sql).not_to match(/LIKE/i)
        end
      end

      context 'when the search is a valid UUID' do
        let(:params) { { search: '75fbcb43-f6f8-4cd1-861f-09a61fd1ddad', searchExtended: '0' } }

        it 'still builds a LIKE scan on text columns (UUIDs stored as text)' do
          expect(builder.perform(Tree.all).to_sql).to match(/LIKE/i)
        end
      end

      context 'when a column is an array uuid type' do
        let(:array_uuid_column) do
          double('Column', name: 'attachment_ids', type: :uuid, array: true).tap do |col|
            allow(col).to receive(:respond_to?).with(:array).and_return(true)
          end
        end

        let(:normal_uuid_column) do
          double('Column', name: 'external_id', type: :uuid, array: false).tap do |col|
            allow(col).to receive(:respond_to?).with(:array).and_return(true)
          end
        end

        before do
          allow(Tree).to receive(:columns).and_return([array_uuid_column, normal_uuid_column])
        end

        it 'searches the array column using ANY() syntax' do
          result = builder.perform(Tree.all)
          expect(result.to_sql).to match(/= ANY.*attachment_ids/i)
        end

        it 'searches the non-array uuid column using equality syntax' do
          result = builder.perform(Tree.all)
          expect(result.to_sql).to match(/"external_id"\s+=\s+'#{search_uuid}'/i)
        end
      end
    end

    describe '#assert_sort_readable!' do
      let(:params) { { sort: sort } }
      let(:user) { { 'id' => '1', 'roleId' => 1, 'rendering_id' => 1 } }

      def write_permissions(collection_reads)
        raw_collections = collection_reads.to_h do |name, readable|
          enabled = { 'roles' => readable ? [1] : [] }
          disabled = { 'roles' => [] }
          [name, {
            'collection' => {
              'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => disabled,
              'addEnabled' => disabled, 'deleteEnabled' => disabled, 'exportEnabled' => disabled
            },
            'actions' => {}
          }]
        end

        # read_permissions may force a real refetch on a denial (a stale cache may sit behind a
        # just-granted permission) — stub the source instead of writing the derived cache directly,
        # so that refetch sees the same permissions rather than hitting the network.
        allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
          .with('/liana/v4/permissions/environment').and_return('collections' => raw_collections)
      end

      before do
        Rails.cache.write('forest.users', { '1' => user })
        Rails.cache.write('forest.has_permission', true)
        Rails.cache.delete('forest.collections') # force a fresh fetch through the stub below, not a leftover from an earlier example
        builder.perform(Tree.all)
      end

      context 'sorting on a column of an unreadable relation' do
        let(:sort) { '-owner.name' }

        it 'refuses, naming the path the sort actually reads' do
          write_permissions('Tree' => true, 'User' => false)

          expect { builder.assert_sort_readable!(user, Tree) }.to raise_error(
            ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
            "You cannot sort on 'owner:name': you are not allowed to read the 'User' collection."
          )
        end

        it 'is served once the relation is readable' do
          write_permissions('Tree' => true, 'User' => true)

          expect { builder.assert_sort_readable!(user, Tree) }.not_to raise_error
        end
      end

      context 'sorting on a path crossing two relations' do
        # detect_reference's own `ref, field = param.split('.')` only ever resolves the first two
        # segments; the guard checks exactly that, not the segment the query never reaches.
        let(:sort) { '-owner.name.extra' }

        it 'checks the same two segments detect_reference resolves, not the dropped third one' do
          write_permissions('Tree' => true, 'User' => false)

          expect { builder.assert_sort_readable!(user, Tree) }.to raise_error(
            ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
            "You cannot sort on 'owner:name': you are not allowed to read the 'User' collection."
          )
        end
      end
    end

    describe 'the footprint it reports' do
      # search_param and the SQL it emits are meant to come from the same `push_condition` calls;
      # this walks the emitted WHERE clause independently of the recording and compares the two as
      # sets of (table, column) pairs, so a leak on either side can't hide behind the other.
      def where_pairs(sql)
        where_clause = sql.split(/\bWHERE\b/i, 2).last || ''
        where_clause.scan(/"?([A-Za-z_]+)"?\.\"?([A-Za-z_]+)"?/).to_set
      end

      def footprint_pairs(root_model, paths)
        paths.map do |path|
          if path.include?(':')
            association, column = path.split(':', 2)
            [root_model.reflect_on_association(association.to_sym).table_name, column]
          else
            [root_model.table_name, path]
          end
        end.to_set
      end

      before { Rails.cache.write('forest.has_permission', false) }

      context 'a plain search matching a root text column and an integer id' do
        let(:params) { { search: '5', searchExtended: '0' } }

        before { Tree.create!(name: 'Oak', age: 5) }
        after { Tree.destroy_all }

        it 'reports exactly the columns the generated WHERE clause reads' do
          records = builder.perform(Tree.all)

          expect(footprint_pairs(Tree, builder.search_field_paths)).to eq(where_pairs(records.to_sql))
        end
      end

      context 'an extended search reaching a to-one relation' do
        let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Robin', searchExtended: '1') }
        let(:builder) { described_class.new(params, [:owner], collection, user) }

        before { Tree.create!(name: 'Oak', owner: User.create!(name: 'Robin')) }
        after { Tree.destroy_all; User.destroy_all }

        it 'reports the associated column alongside the root columns' do
          records = builder.perform(Tree.all)

          expect(footprint_pairs(Tree, builder.search_field_paths)).to eq(where_pairs(records.to_sql))
        end
      end

      context 'an extended search reaching a to-many relation declared via dotted search_fields' do
        let(:collection) do
          ForestLiana::Model::Collection.new(name: 'Island', fields: [], search_fields: %w[name trees.name])
        end
        let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Oak', searchExtended: '1') }

        before { Tree.create!(name: 'Oak', island: Island.create!(name: 'Réunion')) }
        after { Tree.destroy_all; Island.destroy_all }

        it 'reports the associated column, table name distinct from the association name' do
          records = builder.perform(Island.all)

          expect(footprint_pairs(Island, builder.search_field_paths)).to eq(where_pairs(records.to_sql))
        end
      end

      context 'a plain search on a collection whose only search_fields entry is dotted' do
        # A dotted search_fields entry only ever contributes a condition on an extended search
        # (gated by extended_search? above) — a plain one has no column to fall back on either,
        # deliberately: an extended-only search surface answers no records rather than searching
        # nothing scoped and matching everything.
        let(:collection) do
          ForestLiana::Model::Collection.new(name: 'Island', fields: [], search_fields: ['trees.name'])
        end
        let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Oak', searchExtended: '0') }

        before { Tree.create!(name: 'Oak', island: Island.create!(name: 'Réunion')) }
        after { Tree.destroy_all; Island.destroy_all }

        it 'answers no records rather than the whole table' do
          expect(builder.perform(Island.all).count).to eq(0)
        end
      end

      context 'search_fields naming a to-many association the agent does not expose' do
        # Unlike QueryHelper.get_one_associations (used for the to-one block above),
        # SchemaUtils.many_associations does not filter by model_included? on its own — the search
        # site has to, or a search on this collection would report a path into a collection nobody
        # can ever be granted read on, refused as "unexposed" for a config the caller never wrote.
        let(:collection) do
          ForestLiana::Model::Collection.new(name: 'Island', fields: [], search_fields: %w[name trees.name])
        end
        let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Oak', searchExtended: '1') }

        before do
          Tree.create!(name: 'Oak', island: Island.create!(name: 'Réunion'))
          allow(ForestLiana).to receive(:excluded_models).and_return(['Tree'])
        end

        after { Tree.destroy_all; Island.destroy_all }

        it 'does not search it, rather than reporting a path into an unexposed collection' do
          records = builder.perform(Island.all)

          expect(builder.search_field_paths.grep(/\Atrees:/)).to be_empty
          expect(records.to_sql).not_to match(/"trees"/)
        end
      end

      context 'a malformed UUID search' do
        let(:params) { { search: 'abcdef12-3456-4ae-ad4f-5662757713a2', searchExtended: '0' } }

        before { Tree.create!(name: 'Oak'); Tree.create!(name: 'Elm') }
        after { Tree.destroy_all }

        # .to_sql alone can't tell a .none apart from an unfiltered relation — neither has a WHERE
        # clause — so .count (0 for .none, 2 for the whole table) is the assertion that actually
        # distinguishes the two, same tool the sibling specs on this behavior already use.
        it 'reports nothing, matching the .none it falls through to' do
          expect(Tree.count).to eq(2) # the assertion below is vacuous if this precondition drifts
          records = builder.perform(Tree.all)

          expect(builder.search_field_paths).to be_empty
          expect(records.count).to eq(0)
        end
      end

      context 'a polymorphic relation named in an extended search' do
        # Already excluded from the SQL upstream (search_query_builder.rb's own `unless
        # polymorphic?` guard) — this pins that the exclusion carries through to the footprint too,
        # rather than one side silently gaining an entry the other lacks.
        let(:collection) { ForestLiana::Model::Collection.new(name: 'Address', fields: []) }
        let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Robin', searchExtended: '1') }
        let(:builder) { described_class.new(params, [:addressable], collection, user) }

        it 'is absent from both the footprint and the generated SQL' do
          records = builder.perform(Address.all)

          expect(builder.search_field_paths.grep(/\Aaddressable:/)).to be_empty
          expect(records.to_sql).not_to match(/isle|users/i)
        end
      end

      # No case here for acts_as_taggable_on's push site — see the comment on `search_param`'s
      # ActsAsTaggable block for why it's guaranteed by construction rather than spec-covered.
    end

    describe 'when no column can match the search term' do
      let(:collection) { ForestLiana::Model::Collection.new(name: 'Tree', fields: [], search_fields: ['nonexistent']) }
      let(:params) { { search: 'nothing-matches-this', searchExtended: '0' } }

      before { Tree.create!(name: 'Oak') }
      after { Tree.destroy_all }

      it 'answers no records rather than the whole table' do
        expect(builder.perform(Tree.all).count).to eq(0)
      end

      context 'when the collection declares a smart search lambda' do
        before do
          allow(ForestLiana).to receive(:schema_for_resource).and_return(
            ForestLiana::Model::Collection.new(
              name: 'Tree', fields: [{ field: :custom, type: 'String', search: ->(query, _search) { query } }]
            )
          )
        end

        # .count, not .to_sql (see the "a malformed UUID search" context above for why).
        it 'is left unfiltered, since the lambda ORs its own conditions in afterwards' do
          expect(Tree.count).to eq(1) # the assertion below is vacuous if this precondition drifts
          expect(builder.perform(Tree.all).count).to eq(1)
        end

        # The regression a review round caught: a no-op lambda (one that returns its query
        # untouched) sets @lambda_contributed without actually filtering anything - a
        # malformed-UUID search must still be emptied here, the same as it would be with no lambda
        # declared at all. Distinct from the sibling test above, which is an *ordinary* search term
        # + a no-op lambda, correctly served since nothing there was ever suppressed to begin with.
        context 'when the search term is also malformed-UUID-shaped' do
          let(:params) { { search: 'abcdef12-3456-4ae-ad4f-5662757713a2', searchExtended: '0' } }

          it 'is still emptied, since the lambda never actually constrained anything' do
            expect(Tree.count).to eq(1) # the assertion below is vacuous if this precondition drifts
            expect(builder.perform(Tree.all).count).to eq(0)
          end
        end

        # The tradeoff a review round left explicitly unpinned: a lambda that
        # genuinely narrows the query loses to a malformed-UUID-shaped term exactly like a no-op
        # one does, since @lambda_contributed can't currently tell the two apart. Accepted rather
        # than fixed here (closing it needs comparing the lambda's own before/after relation,
        # a larger change than this regression fix) - pinned so it can't drift by accident, and
        # logged in production (search_query_builder.rb) since nothing else would ever surface it.
        context 'when the search term is malformed-UUID-shaped but the lambda genuinely filters' do
          before do
            allow(ForestLiana).to receive(:schema_for_resource).and_return(
              ForestLiana::Model::Collection.new(
                name: 'Tree', fields: [{ field: :custom, type: 'String', search: ->(query, _search) { query.where(name: 'Oak') } }]
              )
            )
          end

          let(:params) { { search: 'abcdef12-3456-4ae-ad4f-5662757713a2', searchExtended: '0' } }

          it 'is still emptied, even though the lambda alone would have matched a real row' do
            expect(Tree.where(name: 'Oak').count).to eq(1) # vacuous otherwise
            expect(builder.perform(Tree.all).count).to eq(0)
          end
        end
      end

      context 'when the declared smart search lambda raises' do
        before do
          allow(ForestLiana).to receive(:schema_for_resource).and_return(
            ForestLiana::Model::Collection.new(
              name: 'Tree',
              fields: [{ field: :custom, type: 'String', search: ->(_query, _search) { raise 'boom' } }]
            )
          )
          allow(FOREST_REPORTER).to receive(:report)
          allow(FOREST_LOGGER).to receive(:error)
        end

        it 'answers no records rather than silently falling through to the unfiltered table' do
          expect(builder.perform(Tree.all).count).to eq(0)
        end
      end

      context 'when one declared lambda raises and a later one succeeds' do
        # @lambda_contributed only ever moves false -> true, never reset — an earlier lambda's
        # failure must not un-set what a later one's success already established.
        before do
          Tree.create!(name: 'Oak')
          allow(ForestLiana).to receive(:schema_for_resource).and_return(
            ForestLiana::Model::Collection.new(
              name: 'Tree',
              fields: [
                { field: :first, type: 'String', search: ->(_query, _search) { raise 'boom' } },
                { field: :second, type: 'String', search: ->(query, _search) { query } }
              ]
            )
          )
          allow(FOREST_REPORTER).to receive(:report)
          allow(FOREST_LOGGER).to receive(:error)
        end

        after { Tree.destroy_all }

        # .count, against the two seeded rows (this context's own, plus the parent context's).
        it 'is served, since the later lambda still constrained the query' do
          expect(builder.perform(Tree.all).count).to eq(2)
        end
      end
    end

    describe 'when a column matches the search term and a declared smart search lambda raises' do
      let(:collection) { ForestLiana::Model::Collection.new(name: 'Tree', fields: []) }
      let(:params) { { search: 'Oak', searchExtended: '0' } }

      before do
        Tree.create!(name: 'Oak')
        Tree.create!(name: 'Elm')
        allow(ForestLiana).to receive(:schema_for_resource).and_return(
          ForestLiana::Model::Collection.new(
            name: 'Tree',
            fields: [{ field: :custom, type: 'String', search: ->(_query, _search) { raise 'boom' } }]
          )
        )
        allow(FOREST_REPORTER).to receive(:report)
        allow(FOREST_LOGGER).to receive(:error)
      end

      after { Tree.destroy_all }

      # The regression a rescue overwriting @records with .none unconditionally would introduce:
      # the column match search_param already found must survive a later lambda's own failure,
      # not be discarded by it.
      it 'still serves the column match, rather than discarding it for the failed lambda' do
        expect(builder.perform(Tree.all).pluck(:name)).to eq(['Oak'])
      end
    end

    describe 'a blank or whitespace-only search' do
      let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: '   ', searchExtended: '1') }

      before { Rails.cache.write('forest.has_permission', false) }

      it 'is served, with nothing to authorize' do
        records = builder.perform(Tree.all)

        expect(records.to_sql).not_to match(/\bWHERE\b/i)
        expect(builder.search_field_paths).to be_empty
      end
    end

    # A smart-field search lambda can read anything, in both modes alike — deliberately never
    # refused (see the comment in #perform): gating a refusal on searchExtended would only cost
    # every customer of this hook their extended search, without closing anything a caller
    # couldn't already reach on the default (plain) path.
    describe 'an extended search on a collection declaring a smart search lambda' do
      let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Robin', searchExtended: extended) }

      before do
        Rails.cache.write('forest.has_permission', true)
        allow(ForestLiana).to receive(:schema_for_resource).and_return(
          ForestLiana::Model::Collection.new(
            name: 'Tree', fields: [{ field: :custom, type: 'String', search: ->(query, _search) { query } }]
          )
        )
      end

      context 'when extended' do
        let(:extended) { '1' }

        it 'is served, not refused' do
          expect { builder.perform(Tree.all) }.not_to raise_error
        end
      end

      context 'when plain' do
        let(:extended) { '0' }

        it 'is served, since what it reads besides the lambda is root-only and pinned readable' do
          expect { builder.perform(Tree.all) }.not_to raise_error
        end
      end
    end

    describe 'a search reaching a column of an unreadable collection' do
      let(:user) { { 'id' => '1', 'roleId' => 1, 'rendering_id' => 1 } }
      let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Robin', searchExtended: '1') }
      let(:builder) { described_class.new(params, [:owner], collection, user) }

      def write_permissions(collection_reads)
        raw_collections = collection_reads.to_h do |name, readable|
          enabled = { 'roles' => readable ? [1] : [] }
          disabled = { 'roles' => [] }
          [name, {
            'collection' => {
              'browseEnabled' => enabled, 'readEnabled' => enabled, 'editEnabled' => disabled,
              'addEnabled' => disabled, 'deleteEnabled' => disabled, 'exportEnabled' => disabled
            },
            'actions' => {}
          }]
        end

        # read_permissions may force a real refetch on a denial (a stale cache may sit behind a
        # just-granted permission) — stub the source instead of writing the derived cache directly,
        # so that refetch sees the same permissions rather than hitting the network.
        allow_any_instance_of(ForestLiana::Ability::Fetch).to receive(:get_permissions)
          .with('/liana/v4/permissions/environment').and_return('collections' => raw_collections)
      end

      before do
        Rails.cache.write('forest.users', { '1' => user })
        Rails.cache.write('forest.has_permission', true)
        Rails.cache.delete('forest.collections') # force a fresh fetch through the stub below, not a leftover from an earlier example
      end

      it 'is refused, naming the path the search actually reads' do
        write_permissions('Tree' => true, 'User' => false)

        expect { builder.perform(Tree.all) }.to raise_error(
          ForestLiana::Ability::Exceptions::UnauthorizedQueryFieldError,
          "You cannot search on 'owner:name': you are not allowed to read the 'User' collection."
        )
      end

      it 'is served once the relation is readable' do
        write_permissions('Tree' => true, 'User' => true)

        expect { builder.perform(Tree.all) }.not_to raise_error
      end
    end

    describe 'the tree it authorizes' do
      let(:raw_filter) { { 'field' => 'name', 'operator' => 'equal', 'value' => 'Oak' } }
      let(:params) { { filters: JSON.generate(raw_filter) } }

      before do
        Rails.cache.write('forest.has_permission', false)
        allow(ForestLiana::ScopeManager).to receive(:append_scope).and_call_original
        allow(ForestLiana::ScopeManager).to receive(:get_scope).and_return(nil)
      end

      # The path guard reads `ScopeManager.inject_context_variables(@params[:filters], @user)`
      # once and hands that same object on to `append_scope`/`FiltersParser` — proving the tree
      # FiltersParser applies is identical to the one the guard read, not a second, independent
      # parse of the same query string that could drift from it.
      it 'hands FiltersParser exactly what it authorized, byte for byte' do
        expected_tree = ForestLiana::ScopeManager.inject_context_variables(params[:filters], user)
        received_tree = nil
        allow(FiltersParser).to receive(:new).and_wrap_original do |original, filters, *rest|
          received_tree = filters
          original.call(filters, *rest)
        end

        builder.perform(Tree.all)

        expect(received_tree).to eq(expected_tree)
      end
    end
  end
end
