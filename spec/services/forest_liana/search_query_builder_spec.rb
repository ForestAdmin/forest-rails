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
