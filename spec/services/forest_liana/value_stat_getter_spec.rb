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

    let(:params) {
      {
        type: "Value",
        collection: collection,
        timezone: "Europe/Paris",
        aggregate: "Count",
        filters: filters
      }
    }

    subject { ValueStatGetter.new(model, params, user) }

    describe 'with empty scopes' do
      let(:scopes) { { } }

      describe 'with a simple filter matching no entries' do
        let(:model) { User }
        let(:collection) { 'users' }
        let(:filters) { { field: 'name', operator: 'in', value: ['Merry', 'Pippin'] }.to_json }

        it 'should have a countCurrent of 0' do
          subject.perform
          expect(subject.record.value[:countCurrent]).to eq 0
        end
      end

      describe 'with a filter on a belongs_to string field' do
        let(:model) { Tree }
        let(:collection) { 'trees' }
        let(:filters) { { field: 'owner:name', operator: 'equal', value: 'Aragorn' }.to_json }

        it 'should have a countCurrent of 2' do
          subject.perform
          expect(subject.record.value[:countCurrent]).to eq 2
        end
      end

      describe 'with a filter on a belongs_to enum field' do
        let(:model) { Tree }
        let(:collection) { 'trees' }
        let(:filters) { { field: 'owner:title', operator: 'equal', value: 'villager' }.to_json }

        it 'should have a countCurrent of 1' do
          subject.perform
          expect(subject.record.value[:countCurrent]).to eq 1
        end
      end
    end

    describe 'with scopes' do
      let(:scopes) {
        {
          'User' => {
            'scope'=> {
              'filter'=> {
                'aggregator' => 'and',
                'conditions' => [
                  { 'field' => 'title', 'operator' => 'not_equal', 'value' => 'villager' }
                ]
              },
              'dynamicScopesValues' => { }
            }
          }
        }
      }

      describe 'with a filter on a belongs_to enum field' do
        let(:model) { User }
        let(:collection) { 'users' }
        let(:filters) { { field: 'title', operator: 'equal', value: 'villager' }.to_json }

        it 'should have a countCurrent of 0' do
          subject.perform
          expect(subject.record.value[:countCurrent]).to eq 0
        end
      end
    end
  end
end
