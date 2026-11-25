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

    describe 'a relation whose scope reads the owner record' do
      let(:tree_scope) do
        { 'aggregator' => 'and', 'conditions' => [{ 'field' => 'name', 'operator' => 'equal', 'value' => 'Lemon Tree' }] }
      end
      let(:scopes) do
        { 'scopes' => { 'Tree' => tree_scope }, 'related_record_scopes' => ['Tree'], 'team' => { 'id' => '1', 'name' => 'Operations' } }
      end

      it 'empties the related record the list did not eager load' do
        lemon_island = Island.create!(name: 'Lemon Tree')
        ginger_island = Island.create!(name: 'Ginger Tree')
        Tree.create!(name: 'Lemon Tree', island: lemon_island, owner: michel, cutter: michel)
        Tree.create!(name: 'Ginger Tree', island: ginger_island, owner: michel, cutter: michel)
        getter = ResourcesGetter.new(
          Island,
          { page: { size: 10, number: 1 }, sort: 'id', fields: { 'Island' => 'id,name,eponymous_tree', 'eponymous_tree' => 'name' } },
          user
        )

        getter.perform
        trees = getter.records.to_a.select { |record| record.name.end_with?('Tree') }.sort_by(&:id).map { |record| record.eponymous_tree&.name }

        expect(trees).to eq(['Lemon Tree', nil])
      end
    end

    describe 'a has_one :through relation' do
      let(:scopes) do
        {
          'scopes' => { 'Location' => { 'aggregator' => 'and', 'conditions' => [{ 'field' => 'coordinates', 'operator' => 'equal', 'value' => 'kept' }] } },
          'related_record_scopes' => ['Location'],
          'team' => { 'id' => '1', 'name' => 'Operations' }
        }
      end

      after { Location.delete_all }

      it 'empties the related record outside its flagged scope' do
        other_island = Island.create!(name: 'Other')
        Location.create!(coordinates: 'kept', island: island)
        Location.create!(coordinates: 'hidden', island: other_island)
        other = Tree.create!(name: 'Other Tree', island: other_island, owner: michel, cutter: michel)
        records = Tree.where(id: [lemon.id, other.id]).order(:id).to_a

        redacted = RelatedRecordScopes.redact(records, Tree, user, nil, [:location])

        expect(redacted.map { |tree| tree.location&.coordinates }).to eq(['kept', nil])
      end
    end

    describe 'a polymorphic relation' do
      after { Address.delete_all }

      it 'empties the targets outside the flagged scope of their own collection' do
        kept = Address.create!(line1: 'a', city: 'c', zipcode: 'z', addressable: michel)
        hidden = Address.create!(line1: 'b', city: 'c', zipcode: 'z', addressable: robert)
        records = Address.where(id: [kept.id, hidden.id]).order(:id).to_a

        redacted = RelatedRecordScopes.redact(records, Address, user, nil, [:addressable])

        expect(redacted.map { |address| address.addressable&.id }).to eq([michel.id, nil])
      end

      context 'when the target collection is not flagged' do
        let(:flagged) { [] }

        it 'serves every target unchanged' do
          hidden = Address.create!(line1: 'b', city: 'c', zipcode: 'z', addressable: robert)

          redacted = RelatedRecordScopes.redact([hidden], Address, user, nil, [:addressable])

          expect(redacted.first.addressable).to eq(robert)
        end
      end
    end

    describe 'a relation whose model cannot be resolved' do
      it 'still empties the out-of-scope related records of the other relations' do
        stub_const('UnresolvedRelationTree', Class.new(ActiveRecord::Base) do
          self.table_name = 'trees'
          belongs_to :owner, class_name: 'User'
          belongs_to :missing, class_name: 'NoSuchModelAnywhere', optional: true
        end)
        records = UnresolvedRelationTree.where(id: [lemon.id, ginger.id]).includes(:owner).to_a

        redacted = RelatedRecordScopes.redact(records, UnresolvedRelationTree, user, nil, [:owner])

        expect(owners_by_tree(redacted)).to eq([[lemon.id, michel.id], [ginger.id, nil]])
      end
    end

    describe 'a related record with a composite primary key', if: Rails.gem_version >= Gem::Version.new('7.1') do
      let(:scopes) do
        {
          'scopes' => { 'Slot' => { 'aggregator' => 'and', 'conditions' => [{ 'field' => 'label', 'operator' => 'equal', 'value' => 'kept' }] } },
          'related_record_scopes' => ['Slot'],
          'team' => { 'id' => '1', 'name' => 'Operations' }
        }
      end

      before do
        connection = ActiveRecord::Base.connection
        connection.create_table(:slots, primary_key: %i[shelf position], force: true) do |t|
          t.integer :shelf
          t.integer :position
          t.string :label
        end
        connection.create_table(:bookings, force: true) do |t|
          t.integer :slot_shelf
          t.integer :slot_position
        end
        stub_const('Slot', Class.new(ActiveRecord::Base) do
          self.table_name = 'slots'
          self.primary_key = %i[shelf position]
        end)
        # Rails 7.1 declares a composite foreign key with query_constraints, 7.2 and later with foreign_key.
        key_option = Rails.gem_version < Gem::Version.new('7.2') ? :query_constraints : :foreign_key
        stub_const('Booking', Class.new(ActiveRecord::Base) do
          self.table_name = 'bookings'
          belongs_to :slot, key_option => %i[slot_shelf slot_position], optional: true
        end)
      end

      after do
        ActiveRecord::Base.connection.drop_table(:bookings, if_exists: true)
        ActiveRecord::Base.connection.drop_table(:slots, if_exists: true)
      end

      it 'compares the keys of each related record as a whole' do
        Slot.create!(shelf: 1, position: 1, label: 'kept')
        Slot.create!(shelf: 1, position: 2, label: 'other')
        Booking.create!(slot_shelf: 1, slot_position: 1)
        Booking.create!(slot_shelf: 1, slot_position: 2)
        records = Booking.order(:id).includes(:slot).to_a

        redacted = RelatedRecordScopes.redact(records, Booking, user, nil, [:slot])

        expect(redacted.map { |booking| booking.slot&.label }).to eq(['kept', nil])
      end
    end
  end
end
