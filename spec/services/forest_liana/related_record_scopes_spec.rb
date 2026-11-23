module ForestLiana
  describe 'scopes on related records' do
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
    let(:owner_scope) do
      { 'aggregator' => 'and', 'conditions' => [{ 'field' => 'name', 'operator' => 'equal', 'value' => 'Michel' }] }
    end
    let(:flagged) { ['User'] }
    let(:scopes) do
      {
        'scopes' => { 'User' => owner_scope },
        'related_record_scopes' => flagged,
        'team' => { 'id' => '1', 'name' => 'Operations' }
      }
    end

    let!(:island) { Island.create!(name: 'Skull') }
    let!(:michel) { User.create!(name: 'Michel') }
    let!(:robert) { User.create!(name: 'Robert') }
    let!(:lemon) { Tree.create!(name: 'Lemon Tree', island: island, owner: michel, cutter: michel) }
    let!(:ginger) { Tree.create!(name: 'Ginger Tree', island: island, owner: robert, cutter: michel) }

    before do
      Rails.cache.write('forest.has_permission', false)
      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
    end

    after { [Tree, User, Island].each(&:delete_all) }

    def owners_by_tree(records)
      records.to_a.sort_by(&:id).map { |tree| [tree.id, tree.owner&.id] }
    end

    describe 'list' do
      let(:getter) do
        ResourcesGetter.new(Tree, { page: { size: 10, number: 1 }, sort: 'id', fields: { 'Tree' => 'id,name,owner', 'owner' => 'name' } }, user)
      end

      it 'empties a related record outside its flagged scope and keeps the row' do
        getter.perform

        expect(owners_by_tree(getter.records)).to eq([[lemon.id, michel.id], [ginger.id, nil]])
      end

      context 'when the related scope is not flagged' do
        let(:flagged) { [] }

        it 'serves the related records unchanged' do
          getter.perform

          expect(owners_by_tree(getter.records)).to eq([[lemon.id, michel.id], [ginger.id, robert.id]])
        end
      end

      context 'when the cached scopes predate the flag' do
        let(:scopes) { { 'scopes' => { 'User' => owner_scope }, 'team' => { 'id' => '1', 'name' => 'Operations' } } }

        it 'serves the related records unchanged' do
          getter.perform

          expect(owners_by_tree(getter.records)).to eq([[lemon.id, michel.id], [ginger.id, robert.id]])
        end
      end
    end

    describe 'get' do
      it 'serves the record with its out-of-scope related record emptied' do
        getter = ResourceGetter.new(Tree, { id: ginger.id.to_s, fields: { 'Tree' => 'id,name,owner', 'owner' => 'name' } }, user)

        getter.perform

        expect(getter.record.owner).to be_nil
      end
    end

    describe 'related list' do
      it 'empties the out-of-scope records reached from the related collection' do
        getter = HasManyGetter.new(
          Island,
          Island.reflect_on_association(:trees),
          { id: island.id.to_s, association_name: 'trees', page: { size: 10, number: 1 }, sort: 'id', fields: { 'Tree' => 'id,name,owner', 'owner' => 'name' } },
          user
        )

        getter.perform

        expect(owners_by_tree(getter.records)).to eq([[lemon.id, michel.id], [ginger.id, nil]])
      end
    end

    describe 'csv batch' do
      it 'empties the out-of-scope related records of a batch' do
        getter = ResourcesGetter.new(Tree, { fields: { 'Tree' => 'id,name,owner', 'owner' => 'name' } }, user)
        getter.perform
        batch = getter.query_for_batch.to_a

        expect(owners_by_tree(getter.redact_related_records(batch))).to eq([[lemon.id, michel.id], [ginger.id, nil]])
      end
    end
  end
end
