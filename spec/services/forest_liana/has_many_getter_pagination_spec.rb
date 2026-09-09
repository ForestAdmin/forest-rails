module ForestLiana
  # Regression test for related-list pagination dropping records.
  # See HasManyGetter#optimize_record_loading: a `has_one` association that actually
  # resolves to MANY rows makes the eager_load JOIN multiply rows, so LIMIT used to
  # collapse a page to fewer DISTINCT records than requested and silently drop the rest.
  describe HasManyGetter, 'pagination with a has_one that is one-to-many in the data' do
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
    let(:scopes) { { 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } } }
    let(:association) { Island.reflect_on_association(:trees) }

    let(:island) { Island.create!(name: 'sicily') }
    let(:page_size) { 2 }
    let(:params) do
      {
        id: island.id,
        association_name: 'trees',
        sort: 'id',
        page: { size: page_size, number: 1 },
        timezone: 'America/Nome'
      }
    end

    subject { described_class.new(Island, association, params, user) }

    before(:each) do
      # A has_one declared on the target model that actually returns MANY rows: every tree
      # sharing the island. Eager-loading it turns one tree into N joined rows.
      Tree.class_eval do
        has_one :island_neighbour, class_name: 'Tree', foreign_key: 'island_id', primary_key: 'island_id'
      end

      @alice = User.create!(name: 'Alice')
      @bob = User.create!(name: 'Bob')
      @trees = [
        Tree.create!(name: 'cedar', island: island, owner: @alice),
        Tree.create!(name: 'olive', island: island, owner: @bob),
        Tree.create!(name: 'pine',  island: island, owner: @alice),
        Tree.create!(name: 'fig',   island: island, owner: @bob)
      ]

      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
    end

    after(:each) do
      # Rails 7.2 switched _reflections/reflections to symbol keys; deleting only the string form
      # is a silent no-op there. Rails 7.2 also memoizes reflect_on_all_associations and only busts
      # that cache from add_reflection, never on a direct _reflections mutation — without the
      # explicit clear, the deleted association keeps leaking into every later spec.
      Tree._reflections.delete('island_neighbour')
      Tree._reflections.delete(:island_neighbour)
      Tree.reflections.delete('island_neighbour')
      Tree.reflections.delete(:island_neighbour)
      Tree.clear_reflections_cache
      %w[island_neighbour island_neighbour= build_island_neighbour
         create_island_neighbour create_island_neighbour! reload_island_neighbour].each do |m|
        Tree.undef_method(m) rescue nil
      end
      Tree.destroy_all
      Island.destroy_all
      User.destroy_all
    end

    it 'still lists the mis-declared has_one among the eager-load candidates' do
      expect(subject.includes).to include(:island_neighbour)
    end

    it 'returns exactly page_size DISTINCT records, not collapsed by the JOIN' do
      subject.perform
      ids = subject.records.map(&:id)

      expect(ids.size).to eq(page_size)
      expect(ids.uniq.size).to eq(page_size)
    end

    it 'does not JOIN the one-to-many association for a base-column sort' do
      subject.perform

      expect(subject.records.to_sql.scan(/LEFT OUTER JOIN/i)).to be_empty
    end

    it 'walks every page yielding all records exactly once' do
      seen = []
      pages = (@trees.size.to_f / page_size).ceil
      pages.times do |i|
        getter = described_class.new(
          Island, association, params.merge(page: { size: page_size, number: i + 1 }), user
        )
        getter.perform
        seen.concat(getter.records.map(&:id))
      end

      expect(seen.sort).to eq(@trees.map(&:id).sort)
      expect(seen.uniq.size).to eq(@trees.size)
    end

    it 'keeps the total count correct' do
      subject.perform

      expect(subject.count).to eq(@trees.size)
    end

    describe 'when sorting by a relation column' do
      let(:params) do
        {
          id: island.id,
          association_name: 'trees',
          sort: 'owner.name',
          page: { size: 15, number: 1 },
          timezone: 'America/Nome'
        }
      end

      it 'keeps the relation joined and returns all records ordered by it' do
        subject.perform
        names = subject.records.to_a.map { |tree| tree.owner.name }

        expect(names.size).to eq(@trees.size)
        expect(names).to eq(names.sort)
      end
    end

    describe 'when filtering by a relation column' do
      let(:params) do
        {
          id: island.id,
          association_name: 'trees',
          filters: { field: 'owner:name', operator: 'equal', value: 'Alice' }.to_json,
          page: { size: 15, number: 1 },
          timezone: 'America/Nome'
        }
      end

      it 'keeps the relation joined and returns only the matching records' do
        subject.perform
        records = subject.records.to_a

        expect(records.size).to eq(2)
        expect(records.map { |tree| tree.owner.name }.uniq).to eq(['Alice'])
      end
    end

    describe 'with extended search across a display-only association' do
      # Regression for review comment on #790: SearchQueryBuilder#search_param, with
      # searchExtended=1, emits `OR LOWER("users"."name") LIKE ...` for every included
      # one-association and relies on that table already being joined. `owner` isn't
      # referenced by sort or filters here, so it would have moved to `preload` (which
      # never joins) and blown up the query with a missing FROM-clause entry.
      let(:params) do
        {
          id: island.id,
          association_name: 'trees',
          search: 'alice',
          'searchExtended' => '1',
          page: { size: 15, number: 1 },
          timezone: 'America/Nome'
        }
      end

      it 'keeps the searched association joined and returns only the matching records' do
        subject.perform
        records = subject.records.to_a

        expect(records.map(&:name)).to contain_exactly('cedar', 'pine')
      end
    end

    describe 'with extended search and an empty search string' do
      let(:params) do
        {
          id: island.id,
          association_name: 'trees',
          search: '',
          'searchExtended' => '1',
          page: { size: 15, number: 1 },
          timezone: 'America/Nome'
        }
      end

      it 'treats an empty search as a no-op instead of building predicates it cannot join' do
        subject.perform

        expect { subject.records.to_a }.not_to raise_error
        expect(subject.records.to_a.map(&:name)).to contain_exactly('cedar', 'olive', 'pine', 'fig')
        expect(subject.count).to eq(@trees.size)
      end

      describe 'with a record whose searched columns are all NULL' do
        before(:each) { Tree.create!(name: nil, island: island) }

        it 'is a no-op, not a filter: the record is still returned' do
          subject.perform

          expect(subject.records.to_a.map(&:name)).to contain_exactly('cedar', 'olive', 'pine', 'fig', nil)
        end
      end
    end
  end
end
