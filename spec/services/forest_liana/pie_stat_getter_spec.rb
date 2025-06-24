module ForestLiana
  describe PieStatGetter do
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
    let(:records) { [
      { name: 'Young Tree n1', age: 3 },
      { name: 'Young Tree n2', age: 3 },
      { name: 'Young Tree n3', age: 3 },
      { name: 'Young Tree n4', age: 3 },
      { name: 'Young Tree n5', age: 3 },
      { name: 'Old Tree n1', age: 15 },
      { name: 'Old Tree n2', age: 15 },
      { name: 'Old Tree n3', age: 15 },
      { name: 'Old Tree n4', age: 15 }
    ] }

    before(:each) do
      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)

      records.each { |record|
        Tree.create!(name: record[:name], age: record[:age])
      }
    end

    describe 'with not allowed aggregator' do
      let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
      let(:model) { Tree }
      let(:collection) { 'trees' }
      let(:params) {
        {
          type: 'Pie',
          sourceCollectionName: collection,
          timezone: 'Europe/Paris',
          aggregator: 'eval',
          groupByFieldName: '`ls`'
        }
      }

      it 'should raise an error' do
        expect {
          PieStatGetter.new(model, params, user)
        }.to raise_error(ForestLiana::Errors::HTTP422Error, 'Invalid aggregate function')
      end
    end

    describe 'with valid aggregate function' do
      let(:model) { Tree }
      let(:collection) { 'trees' }
      let(:params) {
        {
          type: 'Pie',
          sourceCollectionName: collection,
          timezone: 'Europe/Paris',
          aggregator: 'Count',
          groupByFieldName: groupByFieldName
        }
      }

      subject { PieStatGetter.new(model, params, user) }

      describe 'with empty scopes' do
        let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }

        describe 'with an aggregate on the name field' do
          let(:groupByFieldName) { 'name' }

          it 'should be as many categories as records count' do
            subject.perform
            expect(subject.record.value).to match_array([
              {:key => "Old Tree n1", :value => 1},
              {:key => "Old Tree n2", :value => 1},
              {:key => "Old Tree n3", :value => 1},
              {:key => "Old Tree n4", :value => 1},
              {:key => "Young Tree n1", :value => 1},
              {:key => "Young Tree n2", :value => 1},
              {:key => "Young Tree n3", :value => 1},
              {:key => "Young Tree n4", :value => 1},
              {:key => "Young Tree n5", :value => 1}
            ])
          end
        end

        describe 'with an aggregate on the age field' do
          let(:groupByFieldName) { 'age' }

          it 'should be as many categories as different ages among records' do
            subject.perform
            expect(subject.record.value).to eq [{ :key => 3, :value => 5}, { :key => 15, :value => 4 }]
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
                  'conditions' => [{'field' => 'age', 'operator' => 'less_than', 'value' => 10}]
                }
              },
            'team' => {
              'id' => 43,
              'name' => 'Operations'
            }
          }
        }

        describe 'with an aggregate on the name field' do
          let(:groupByFieldName) { 'name' }

          it 'should be as many categories as records inside the scope' do
            subject.perform
            expect(subject.record.value).to match_array([
              {:key => "Young Tree n1", :value => 1},
              {:key => "Young Tree n2", :value => 1},
              {:key => "Young Tree n3", :value => 1},
              {:key => "Young Tree n4", :value => 1},
              {:key => "Young Tree n5", :value => 1}
            ])
          end
        end

        describe 'with an aggregate on the age field' do
          let(:groupByFieldName) { 'age' }

          it 'should be only one category' do
            subject.perform
            expect(subject.record.value).to eq [{ :key => 3, :value => 5}]
          end
        end
      end
    end

    describe 'order method behavior' do
      let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
      let(:model) { Tree }
      let(:collection) { 'trees' }
      let(:groupByFieldName) { 'age' }

      describe 'with COUNT aggregator' do
        let(:params) {
          {
            type: 'Pie',
            sourceCollectionName: collection,
            timezone: 'Europe/Paris',
            aggregator: 'Count',
            groupByFieldName: groupByFieldName
          }
        }

        subject { PieStatGetter.new(model, params, user) }

        it 'should use Arel.sql for COUNT order and return results in descending order' do
          subject.perform

          # Verify results are ordered by count descending (5 young trees, 4 old trees)
          expect(subject.record.value).to eq [
                                               { :key => 3, :value => 5},
                                               { :key => 15, :value => 4 }
                                             ]
        end

        it 'should return an Arel::Nodes::SqlLiteral for order method' do
          order_result = subject.send(:order)
          expect(order_result).to be_a(Arel::Nodes::SqlLiteral)
          expect(order_result.to_s).to match(/COUNT.*DESC/i)
        end
      end

      describe 'with SUM aggregator' do
        let(:params) {
          {
            type: 'Pie',
            sourceCollectionName: collection,
            timezone: 'Europe/Paris',
            aggregator: 'Sum',
            aggregateFieldName: 'age',
            groupByFieldName: groupByFieldName
          }
        }

        subject { PieStatGetter.new(model, params, user) }

        it 'should use Arel.sql for SUM order and return results in descending order' do
          subject.perform

          # Verify results are ordered by sum descending (15*4=60 > 3*5=15)
          expect(subject.record.value).to eq [
                                               { :key => 15, :value => 60 },
                                               { :key => 3, :value => 15 }
                                             ]
        end

        it 'should return an Arel::Nodes::SqlLiteral for order method' do
          order_result = subject.send(:order)
          expect(order_result).to be_a(Arel::Nodes::SqlLiteral)
          expect(order_result.to_s).to match(/sum_age.*DESC/i)
        end
      end

      describe 'order method returns Arel SQL' do
        let(:params) {
          {
            type: 'Pie',
            sourceCollectionName: collection,
            timezone: 'Europe/Paris',
            aggregator: 'Count',
            groupByFieldName: groupByFieldName
          }
        }

        subject { PieStatGetter.new(model, params, user) }

        it 'should return an Arel::Nodes::SqlLiteral with COUNT function' do
          order_result = subject.send(:order)
          expect(order_result).to be_a(Arel::Nodes::SqlLiteral)
          expect(order_result.to_s).to match(/COUNT.*DESC/i)
        end
      end
    end
  end
end
