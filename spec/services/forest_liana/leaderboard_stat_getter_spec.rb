module ForestLiana
  describe LeaderboardStatGetter do
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
    let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }

    before(:each) do
      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
    end

    describe 'on a relationship whose model does not belong to the parent collection' do
      let(:params) {
        {
          type: 'Leaderboard',
          timezone: 'Europe/Paris',
          relationshipFieldName: 'addresses',
          labelFieldName: 'name',
          aggregator: 'Count',
          limit: 5
        }
      }

      before(:each) do
        king = User.create!(name: 'Aegon', title: 'king')
        villager = User.create!(name: 'Davos', title: 'villager')

        2.times { |index| Address.create!(line1: "#{index} Dragonstone", addressable: king) }
        Address.create!(line1: '1 Flea Bottom', addressable: villager)
      end

      it 'ranks the parent records by number of related records' do
        getter = LeaderboardStatGetter.new(User, params, user)
        getter.perform

        expect(getter.record.value).to eq([
          { key: 'Aegon', value: 2 },
          { key: 'Davos', value: 1 }
        ])
      end
    end

    describe 'on a relationship whose model belongs to the parent collection' do
      let(:aggregator) { 'Count' }
      let(:aggregate_field) { nil }
      let(:params) {
        {
          type: 'Leaderboard',
          timezone: 'Europe/Paris',
          relationshipFieldName: 'trees',
          labelFieldName: 'name',
          aggregator: aggregator,
          aggregateFieldName: aggregate_field,
          limit: 5
        }
      }

      before(:each) do
        dragonstone = Island.create!(name: 'Dragonstone')
        skagos = Island.create!(name: 'Skagos')

        Tree.create!(name: 'Old Tree', age: 15, island: dragonstone)
        Tree.create!(name: 'Young Tree', age: 3, island: dragonstone)
        Tree.create!(name: 'Lone Tree', age: 30, island: skagos)
      end

      it 'counts the related records, not the parent ones' do
        getter = LeaderboardStatGetter.new(Island, params, user)
        getter.perform

        expect(getter.record.value).to eq([
          { key: 'Dragonstone', value: 2 },
          { key: 'Skagos', value: 1 }
        ])
      end

      context 'when the chart sums a field of the related records' do
        let(:aggregator) { 'Sum' }
        let(:aggregate_field) { 'age' }

        it 'sums that field on the related model' do
          getter = LeaderboardStatGetter.new(Island, params, user)
          getter.perform

          expect(getter.record.value).to eq([
            { key: 'Skagos', value: 30 },
            { key: 'Dragonstone', value: 18 }
          ])
        end
      end
    end
  end
end
