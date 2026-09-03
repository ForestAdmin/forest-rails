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
        permissions = collection_reads.to_h do |name, readable|
          [name, { 'browse' => readable ? [1] : [], 'read' => readable ? [1] : [], 'edit' => [], 'add' => [], 'delete' => [], 'export' => [], :actions => {} }]
        end

        Rails.cache.write('forest.collections', permissions)
      end

      before do
        Rails.cache.write('forest.users', { '1' => user })
        Rails.cache.write('forest.has_permission', true)
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

        it 'reports nothing, matching the WHERE-less query it falls through to' do
          records = builder.perform(Tree.all)

          expect(builder.search_field_paths).to be_empty
          expect(records.to_sql).not_to match(/\bWHERE\b/i)
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

        it 'is left unfiltered, since the lambda ORs its own conditions in afterwards' do
          expect(builder.perform(Tree.all).to_sql).not_to match(/\bWHERE\b/i)
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

    describe 'an extended search on a collection declaring a smart search lambda' do
      let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Robin', searchExtended: extended) }

      before do
        allow(ForestLiana).to receive(:schema_for_resource).and_return(
          ForestLiana::Model::Collection.new(
            name: 'Tree', fields: [{ field: :custom, type: 'String', search: ->(query, _search) { query } }]
          )
        )
      end

      context 'when extended' do
        let(:extended) { '1' }

        it 'is refused, since the lambda can read anything and nothing describes what' do
          Rails.cache.write('forest.has_permission', true)

          expect { builder.perform(Tree.all) }.to raise_error(
            ForestLiana::Ability::Exceptions::UndescribableSearchError,
            "You cannot run an extended search on the 'Tree' collection: the fields it reaches " \
              'cannot be determined, so they cannot be checked against your permissions.'
          )
        end

        it 'is served when there is no permission system to check against' do
          Rails.cache.write('forest.has_permission', false)

          expect { builder.perform(Tree.all) }.not_to raise_error
        end
      end

      context 'when plain' do
        let(:extended) { '0' }

        it 'is served, since what it reads besides the lambda is root-only and pinned readable' do
          Rails.cache.write('forest.has_permission', true)

          expect { builder.perform(Tree.all) }.not_to raise_error
        end
      end
    end

    describe 'a search reaching a column of an unreadable collection' do
      let(:user) { { 'id' => '1', 'roleId' => 1, 'rendering_id' => 1 } }
      let(:params) { ActiveSupport::HashWithIndifferentAccess.new(search: 'Robin', searchExtended: '1') }
      let(:builder) { described_class.new(params, [:owner], collection, user) }

      def write_permissions(collection_reads)
        permissions = collection_reads.to_h do |name, readable|
          [name, { 'browse' => readable ? [1] : [], 'read' => readable ? [1] : [], 'edit' => [], 'add' => [], 'delete' => [], 'export' => [], :actions => {} }]
        end

        Rails.cache.write('forest.collections', permissions)
      end

      before do
        Rails.cache.write('forest.users', { '1' => user })
        Rails.cache.write('forest.has_permission', true)
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
