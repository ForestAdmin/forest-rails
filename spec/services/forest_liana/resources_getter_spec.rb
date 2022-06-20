module ForestLiana
  describe ResourcesGetter do
    let(:resource) { User }
    let(:pageSize) { 10 }
    let(:pageNumber) { 1 }
    let(:sort) { 'id' }
    let(:fields) { }
    let(:filters) { }
    let(:scopes) { { } }
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }

    let(:getter) { described_class.new(resource, {
      page: { size: pageSize, number: pageNumber },
      sort: sort,
      fields: fields,
      filters: filters,
    }, user) }

    def init_scopes
      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
    end

    before(:each) do
      users = ['Michel', 'Robert', 'Vince', 'Sandro', 'Olesya', 'Romain', 'Valentin', 'Jason', 'Arnaud', 'Jeff', 'Steve', 'Marc', 'Xavier', 'Paul', 'Mickael', 'Mike', 'Maxime', 'Gertrude', 'Monique', 'Mia', 'Rachid', 'Edouard', 'Sacha', 'Caro', 'Amand', 'Nathan', 'Noémie', 'Robin', 'Gaelle', 'Isabelle']
      .map { |name| User.create(name: name) }

      islands = [
        { :name => 'Skull', :updated_at => Time.now - 1.years },
        { :name => 'Muerta', :updated_at => Time.now - 5.years },
        { :name => 'Treasure', :updated_at => Time.now },
        { :name => 'Birds', :updated_at => Time.now - 7.years },
        { :name => 'Lille', :updated_at => Time.now - 1.years }
      ].map { |island| Island.create(name: island[:name], updated_at: island[:updated_at]) }

      trees = [
        { :name => 'Lemon Tree', :created_at => Time.now - 7.years, :island => islands[0], :owner => users[0], :cutter => users[0] },
        { :name => 'Ginger Tree', :created_at => Time.now - 7.years, :island => islands[0], :owner => users[1], :cutter => users[0] },
        { :name => 'Apple Tree', :created_at => Time.now - 5.years, :island => islands[1], :owner => users[2], :cutter => users[0] },
        { :name => 'Pear Tree', :created_at => Time.now + 4.hours, :island => islands[3], :owner => users[3], :cutter => users[1] },
        { :name => 'Choco Tree', :created_at => Time.now, :island => islands[3], :owner => users[4], :cutter => users[1] }
      ].map { |tree| Tree.create(name: tree[:name], created_at: tree[:created_at], island: tree[:island], owner: tree[:owner], cutter: tree[:cutter]) }

      locations = [
        { :coordinates => '12345', :island => islands[0] },
        { :coordinates => '54321', :island => islands[1] },
        { :coordinates => '43215', :island => islands[2] },
        { :coordinates => '21543', :island => islands[3] },
        { :coordinates => '32154', :island => islands[4] }
      ].map { |location| Location.create(coordinates: location[:coordinates], island: location[:island]) }

      reference = Reference.create()
      init_scopes
    end

    after(:each) do
      User.destroy_all
      Island.destroy_all
      Location.destroy_all
      Tree.destroy_all
    end

    describe 'when there are more records than the page size' do
      describe 'when asking for the 1st page and 15 records' do
        let(:pageSize) { 15 }
        let(:sort) { '-id' }

        it 'should get only the expected records' do
          getter.perform
          records = getter.records
          count = getter.count

          expect(records.count).to eq 15
          expect(count).to eq 30
          expect(records.first.id).to eq 30
          expect(records.last.id).to eq 16
        end
      end

      describe 'when asking for the 2nd page and 10 records' do
        let(:pageNumber) { 2 }
        let(:sort) { '-id' }

        it 'should get only the expected records' do
          getter.perform
          records = getter.records
          count = getter.count

          expect(records.count).to eq 10
          expect(count).to eq 30
          expect(records.first.id).to eq 20
          expect(records.last.id).to eq 11
        end
      end
    end

    describe 'when on a model having a reserved SQL word as name' do
      let(:resource) { Reference }

      it 'should get the ressource properly' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 1
        expect(count).to eq 1
        expect(records.first.id).to eq 1
      end
    end

    describe 'when sorting by a specific field' do
      let(:pageSize) { 5 }
      let(:sort) { '-name' }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 5
        expect(count).to eq 30
        expect(records.map(&:name)).to eq ['Xavier', 'Vince', 'Valentin', 'Steve', 'Sandro']
      end
    end

    describe 'when sorting by a belongs_to association' do
      let(:resource) { Tree }
      let(:sort) { 'owner.name' }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 5
        expect(count).to eq 5
        expect(records.map(&:id)).to eq [1, 5, 2, 4, 3]
      end
    end

    describe 'when sorting by a has_one association' do
      let(:resource) { Island }
      let(:sort) { 'location.coordinates' }
      let(:pageSize) { 5 }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 5
        expect(count).to eq 5
        expect(records.map(&:id)).to eq [1, 4, 5, 3, 2]
      end
    end

    describe 'when getting instance dependent associations' do
      let(:resource) { Island }
      let(:fields) { { 'Island' => 'id,eponymous_tree', 'eponymous_tree' => 'id,name'} }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq Island.count
        expect(count).to eq Island.count
        expect(records.map(&:name)).to match_array(Island.pluck(:name))
      end
    end

    describe 'when filtering on an ambiguous field' do
      let(:resource) { Tree }
      let(:pageSize) { 5 }
      let(:fields) { { 'Tree' => 'id' } }
      let(:filters) { {
        aggregator: 'and',
        conditions: [{
          field: 'created_at',
          operator: 'after',
          value: "#{Time.now - 6.year}",
        }, {
          field: 'cutter:name',
          operator: 'equal',
          value: 'Michel'
        }]
      }.to_json }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 1
        expect(count).to eq 1
        expect(records.first.id).to eq 3
        expect(records.first.name).to eq 'Apple Tree'
        expect(records.first.cutter.name).to eq 'Michel'
      end
    end

    describe 'when filtering on before x hours ago' do
      let(:resource) { Tree }
      let(:fields) { { 'Tree' => 'id' } }
      let(:filters) { {
        field: 'created_at',
        operator: 'before_x_hours_ago',
        value: 3
      }.to_json }

      it 'should filter as expected' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 3
        expect(count).to eq 3
        expect(records.map(&:name)).to eq ['Lemon Tree', 'Ginger Tree', 'Apple Tree']
      end
    end

    describe 'when filtering on after x hours ago' do
      let(:resource) { Tree }
      let(:fields) { { 'Tree' => 'id' } }
      let(:filters) { {
        field: 'created_at',
        operator: 'after_x_hours_ago',
        value: 3
      }.to_json }

      it 'should filter as expected' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 2
        expect(count).to eq 2
        expect(records.map(&:name)).to eq ['Pear Tree', 'Choco Tree']
      end
    end

    describe 'when sorting on an ambiguous field name with a filter' do
      let(:resource) { Tree }
      let(:sort) { '-name' }
      let(:fields) { { 'Tree' => 'id' } }
      let(:filters) { {
        field: 'cutter:name',
        operator: 'equal',
        value: 'Michel'
      }.to_json }

      it 'should get only the sorted expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 3
        expect(count).to eq 3
        expect(records.map(&:name)).to eq ['Lemon Tree', 'Ginger Tree', 'Apple Tree']
      end
    end

    describe 'when filtering on an updated_at field of the main collection' do
      let(:resource) { Island }
      let(:filters) { {
        field: 'updated_at',
        operator: 'previous_year'
      }.to_json }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 2
        expect(count).to eq 2
        expect(records.map(&:name)).to eq ['Skull', 'Lille']
      end
    end

    describe 'when filtering on an updated_at field of an associated collection' do
      let(:resource) { Tree }
      let(:fields) { { 'Tree' => 'id' } }
      let(:filters) { {
        field: 'island:updated_at',
        operator: 'previous_year'
      }.to_json }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 2
        expect(count).to eq 2
        expect(records.map(&:name)).to eq ['Lemon Tree', 'Ginger Tree']
      end
    end

    describe 'when filtering on an exact updated_at field of an associated collection' do
      let(:resource) { Tree }
      let(:fields) { { 'Tree' => 'id' } }
      let(:filters) { {
        field: 'island:updated_at',
        operator: 'equal',
        value: 'Sat Jul 02 2016 11:52:00 GMT-0400 (EDT)',
      }.to_json }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 0
        expect(count).to eq 0
      end
    end

    describe 'when filtering on a field of an associated collection that does not exist' do
      let(:resource) { Tree }
      let(:fields) { { 'Tree' => 'id' } }
      let(:filters) { {
        field: 'leaf:id',
        operator: 'equal',
        value: 1
      }.to_json }

      it 'should raise the right error' do
        expect { getter }.to raise_error(ForestLiana::Errors::HTTP422Error, "Association 'leaf' not found")
      end
    end

    describe 'when filtering on a field that does not exists' do
      let(:resource) { Tree }
      let(:fields) { { 'Tree' => 'id' } }
      let(:filters) { {
        field: 'content',
        operator: 'contains',
        value: 'c'
      }.to_json }

      it 'should raise the right error' do
        expect { getter }.to raise_error(ForestLiana::Errors::HTTP422Error, "Field 'content' not found")
      end
    end

    describe 'when filtering on a smart field' do
      let(:filters) { {
        field: 'cap_name',
        operator: 'equal',
        value: 'MICHEL',
      }.to_json }

      it 'should filter as expected' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 1
        expect(count).to eq 1
        expect(records.first.id).to eq 1
        expect(records.first.name).to eq 'Michel'
      end
    end

    describe 'when filtering on a smart field with no filter method' do
      let(:resource) { Location }
      let(:filters) { {
        field: 'alter_coordinates',
        operator: 'equal',
        value: '12345XYZ',
      }.to_json }

      it 'should raise the right error' do
        expect { getter }.to raise_error(
          ForestLiana::Errors::NotImplementedMethodError,
           "method filter on smart field 'alter_coordinates' not found"
        )
      end
    end

    describe 'when scopes are defined' do
      let(:resource) { Island }
      let(:pageSize) { 15 }
      let(:fields) { }
      let(:filters) { }
      let(:scopes) {
        {
          'Island' => {
            'scope'=> {
              'filter'=> {
                'aggregator' => 'and',
                'conditions' => [
                  { 'field' => 'name', 'operator' => 'contains', 'value' => 'u' }
                ]
              },
              'dynamicScopesValues' => { }
            }
          }
        }
      }

      describe 'when there are NO filters already defined' do
        it 'should get only the records matching the scope' do
          getter.perform
          records = getter.records
          count = getter.count

          expect(records.count).to eq 3
          expect(count).to eq 3
          expect(records.first.name).to eq 'Skull'
          expect(records.second.name).to eq 'Muerta'
          expect(records.third.name).to eq 'Treasure'
        end
      end

      describe 'when there are filters already defined' do
        let(:filters) { {
          aggregator: 'and',
          conditions: [{
            field: 'name',
            operator: 'contains',
            value: 'a',
          }]
        }.to_json }

        it 'should get only the records matching the scope' do
          getter.perform
          records = getter.records
          count = getter.count

          expect(records.count).to eq 2
          expect(count).to eq 2
          expect(records.first.name).to eq 'Muerta'
          expect(records.second.name).to eq 'Treasure'
        end
      end
    end
  end
end
