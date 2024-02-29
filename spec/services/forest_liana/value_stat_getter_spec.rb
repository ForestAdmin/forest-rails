module ForestLiana
  describe ValueStatGetter do
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }

    before(:each) do
      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)

      island = Island.create!(name: 'Númenor')
      king = User.create!(title: :king, name: 'Aragorn')
      villager = User.create!(title: :villager)
      Tree.create!(name: 'Tree n1', age: 1, island: island, owner: king)
      Tree.create!(name: 'Tree n2', age: 3, island: island, created_at: 3.day.ago, owner: villager)
      Tree.create!(name: 'Tree n3', age: 4, island: island, owner: king, cutter: villager)
    end

    describe 'with not allowed aggregator' do
      let(:model) { User }
      let(:collection) { 'users' }
      let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
      let(:params) {
        {
          type: "Value",
          sourceCollectionName: collection,
          timezone: "Europe/Paris",
          aggregator: "eval",
          aggregateFieldName: "`ls`"
        }
      }

      it 'should raise an error' do
        expect {
          ValueStatGetter.new(model, params, user)
        }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Invalid aggregate function')
      end
    end

    describe 'with valid aggregate function' do
      let(:params) {
        {
          type: "Value",
          sourceCollectionName: sourceCollectionName,
          timezone: "Europe/Paris",
          aggregator: "Count",
          filter: filter
        }
      }

      subject { ValueStatGetter.new(model, params, user) }

      describe 'with empty scopes' do
        let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }

        describe 'with a simple filter matching no entries' do
          let(:model) { User }
          let(:sourceCollectionName) { 'users' }
          let(:filter) { { field: 'name', operator: 'in', value: ['Merry', 'Pippin'] }.to_json }

          it 'should have a countCurrent of 0' do
            subject.perform
            expect(subject.record.value[:countCurrent]).to eq 0
          end
        end

        describe 'with a filter on a belongs_to string field' do
          let(:model) { Tree }
          let(:sourceCollectionName) { 'trees' }
          let(:filter) { { field: 'owner:name', operator: 'equal', value: 'Aragorn' }.to_json }

          it 'should have a countCurrent of 2' do
            subject.perform
            expect(subject.record.value[:countCurrent]).to eq 2
          end
        end

        describe 'with a filter on a belongs_to enum field' do
          let(:model) { Tree }
          let(:sourceCollectionName) { 'trees' }
          let(:filter) { { field: 'owner:title', operator: 'equal', value: 'villager' }.to_json }

          it 'should have a countCurrent of 1' do
            subject.perform
            expect(subject.record.value[:countCurrent]).to eq 1
          end
        end
      end

      describe 'with scopes' do
        let(:scopes) {
          {
            'scopes' =>
              {
                'User' => {
                  'aggregator' => 'and',
                  'conditions' => [{'field' => 'title', 'operator' => 'not_equal', 'value' => 'villager'}]
                }
              },
            'team' => {
              'id' => 43,
              'name' => 'Operations'
            }
          }
        }

        describe 'with a filter on a belongs_to enum field' do
          let(:model) { User }
          let(:sourceCollectionName) { 'users' }
          let(:filter) { { field: 'title', operator: 'equal', value: 'villager' }.to_json }

          it 'should have a countCurrent of 0' do
            subject.perform
            expect(subject.record.value[:countCurrent]).to eq 0
          end
        end
      end
    end
  end
end
