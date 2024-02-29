module ForestLiana
  describe HasManyGetter do
    describe 'when retrieving has many relationship related records' do
      let(:rendering_id) { 13 }
      let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
      let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
      let(:association) { Island.reflect_on_association(:trees) }
      let(:params) {
        {
          id: Island.first.id,
          association_name: 'trees',
          page: { size: 15, number: 1 },
          timezone: 'America/Nome'
        }
      }

      subject {
        described_class.new(Island, association, params, user)
      }

      before(:each) do
        madagascar = Island.create(name: 'madagascar')
        re = Island.create(name: 'ré')
        Tree.create(name: 'lemon tree', island: madagascar)
        Tree.create(name: 'banana tree', island: madagascar)
        Tree.create(name: 'papaya tree', island: madagascar)
        Tree.create(name: 'apple tree', island: re)
        Tree.create(name: 'banana tree', island: re)
        ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
        allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
      end

      after(:each) do
        Island.destroy_all
        Tree.destroy_all
      end

      describe 'with empty scopes' do
        describe 'with page 1 size 15' do
          it 'should return the 3 trees matching madagascar' do
            subject.perform

            expect(subject.records.count).to eq 3
            expect(subject.count).to eq 3
          end
        end

        describe 'when sorting by decreasing id' do
          let(:params) {
            {
              id: Island.first.id,
              association_name: 'trees',
              sort: '-id',
              page: { size: 15, number: 1 },
              timezone: 'America/Nome'
            }
          }

          it 'should order records properly' do
            subject.perform

            expect(subject.records.count).to eq 3
            expect(subject.count).to eq 3
            expect(subject.records.first.id).to be > subject.records.last.id
          end
        end

        describe 'when searching for banana tree' do
          let(:params) {
            {
              id: Island.first.id,
              association_name: 'trees',
              search: 'banana',
              page: { size: 15, number: 1 },
              timezone: 'America/Nome'
            }
          }

          it 'should return only the banana tree linked to madagascar' do
            subject.perform

            expect(subject.records.count).to eq 1
            expect(subject.count).to eq 1
            expect(subject.records.first.island.name).to eq 'madagascar'
          end
        end
      end

      describe 'with scopes' do
        let(:scopes) {
          {
            'scopes' =>
              {
                'Tree' => {
                  'aggregator' => 'and',
                  'conditions' => [{'field' => 'name', 'operator' => 'contains', 'value' => 'a'}]
                }
              },
            'team' => {
              'id' => 43,
              'name' => 'Operations'
            }
          }
        }

        describe 'when asking for all trees related to madagascar' do
          it 'should return trees belonging to madagascar and matching the scopes' do
            subject.perform

            # Only `papaya` and `banana` contain an `a`
            expect(subject.records.count).to eq 2
            expect(subject.count).to eq 2
          end
        end
      end
    end
  end
end
