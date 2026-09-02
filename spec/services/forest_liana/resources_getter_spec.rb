module ForestLiana
  describe ResourcesGetter do
    let(:resource) { User }
    let(:pageSize) { 10 }
    let(:pageNumber) { 1 }
    let(:sort) { 'id' }
    let(:fields) { { resource.name => 'id' } }
    let(:filters) {}
    let(:scopes) { {'scopes' => {}, 'team' => {'id' => '1', 'name' => 'Operations'}} }
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }

    let(:getter) { described_class.new(resource, {
      page: { size: pageSize, number: pageNumber },
      sort: sort,
      fields: fields,
      filters: filters,
    }, user) }

    before(:each) do
      # This file exercises SQL shaping, not permissions: without this, the read-permission
      # guard on filters/sort hits the real permissions API through whatever the process-wide
      # (file-backed) cache last left behind, rather than the "nothing to check" this file assumes.
      Rails.cache.write('forest.has_permission', false)
    end

    def init_scopes
      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
    end

    def clean_database
      [
        Driver,
        Island,
        Location,
        Manufacturer,
        Product,
        Tree,
        User,
      ].each(&:destroy_all)
    end

    before(:each) do
      clean_database

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

      manufacturers = ['Orange', 'Pear'].map { |name| Manufacturer.create!(name: 'name') }

      drivers = ['Baby driver', 'Taxi driver'].map { |firstname| Driver.create!(firstname: firstname) }

      products = [
        { name: 'Valencia', uri: 'https://valencia.com', manufacturer: manufacturers[0], driver: drivers[0] },
        { name: 'Blood', uri: 'https://blood.com', manufacturer: manufacturers[0], driver: drivers[1] },
        { name: 'Conference', uri: 'https://conference.com', manufacturer: manufacturers[1], driver: drivers[0] },
        { name: 'Concorde', uri: 'https://concorde.com', manufacturer: manufacturers[1], driver: drivers[1] }
      ].map {|attributes| Product.create!(attributes) }

      reference = Reference.create()
      init_scopes
    end

    describe 'records eager loading' do
      let(:resource) { Product }
      let(:fields) { { resource.name => 'id,name,manufacturer', 'manufacturer' => 'name' } }

      shared_examples 'records' do
        it 'should get only the expected records' do
          getter.perform

          records = getter.records

          count = getter.count

          expect(records.count).to eq 4
          expect(count).to eq 4
          expect(records.map(&:name)).to match_array(%w[Valencia Blood Conference Concorde])
        end
      end

      context 'when the included association is in the same database' do
        it 'performs a left outer join with the association' do
          expect(getter.perform.to_sql).to match(/LEFT OUTER JOIN "manufacturers"/)
        end

        include_examples 'records'
      end

      context 'when the included association is in a different database' do
        let(:fields) { { resource.name => 'id,name,driver', 'driver' => 'firstname' } }

        it 'does not perform a left outer join with the association' do
          expect(getter.perform.to_sql).not_to match(/LEFT OUTER JOIN "drivers"/)
        end

        include_examples 'records'
      end

      it 'resolves the database without issuing a SQL query' do
        getter

        queries = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          queries << payload[:sql] unless payload[:name] == 'SCHEMA' || payload[:cached]
        end
        begin
          getter.send(:separate_database?, Product, Product.reflect_on_association(:manufacturer))
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        expect(queries).to be_empty
      end
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

    describe '.fetch_ids' do
      it 'returns all the matching ids when no limit is given' do
        expect(described_class.fetch_ids(getter).length).to eq 30
      end

      it 'returns at most limit ids' do
        expect(described_class.fetch_ids(getter, limit: 5).length).to eq 5
      end
    end

    describe '.filter_excluded_ids' do
      it 'removes excluded simple ids' do
        expect(described_class.filter_excluded_ids([1, 2, 3], ['2'])).to eq [1, 3]
      end

      it 'removes excluded composite ids given in their serialized JSON form' do
        expect(described_class.filter_excluded_ids([[1, 'abc'], [2, 'def']], ['[1,"abc"]']))
          .to eq [[2, 'def']]
      end

      it 'returns the ids untouched without exclusions' do
        expect(described_class.filter_excluded_ids([1, 2], [])).to eq [1, 2]
        expect(described_class.filter_excluded_ids([1, 2], nil)).to eq [1, 2]
      end
    end

    describe 'when on a model having a reserved SQL word as name' do
      let(:resource) { Reference }
      let(:fields) { { resource.name => 'id' } }

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
      let(:fields) { { resource.name => 'id' } }
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

    context 'when fields is given' do
      let(:resource) { Island }
      let(:filters) { {
        field: 'location:id',
        operator: 'equal',
        value: 1,
      }.to_json }

      it 'should get only the expected records' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq 1
        expect(count).to eq 1
        expect(records.map(&:id)).to eq [1]
      end

      it 'should include associated table only once' do
        sql_query = getter.perform.to_sql
        location_includes_count = sql_query.scan('LEFT OUTER JOIN "locations"').count
        expect(location_includes_count).to eq(1)
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

    describe 'when getting a has_one through association' do
      let(:resource) { Tree }
      let(:fields) { { 'Tree' => 'id,location' } }

      it 'should get the expected records, including the foreign_key for the direct association' do
        getter.perform
        records = getter.records
        count = getter.count

        expect(records.count).to eq Tree.count
        expect(count).to eq Tree.count
        expect(records.map(&:id)).to match_array(Tree.pluck(:id))
        expect(records.map(&:island_id)).to match_array(Tree.pluck(:island_id))
      end
    end

    describe 'when filtering on an ambiguous field' do
      let(:resource) { Tree }
      let(:pageSize) { 5 }
      let(:fields) { { 'Tree' => 'id,name', 'cutter' => 'id' } }
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
      let(:fields) { { 'Tree' => 'id,name' } }
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
      let(:fields) { { 'Tree' => 'id,name' } }
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
      let(:fields) { { resource.name => 'id' } }
      let(:filters) { }
      let(:scopes) {
        {
          'scopes' =>
            {
              'Island' => {
                'aggregator' => 'and',
                'conditions' => [{'field' => 'name', 'operator' => 'contains', 'value' => 'u'}]
              }
            },
          'team' => {
            'id' => 43,
            'name' => 'Operations'
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

      describe '#perform' do
        let(:resource) { User }
        let(:fields) { nil }
        let(:sort) { nil }
        let(:filters) { nil }

        it 'does not raise an error when params[:fields] is nil' do
          expect {
            getter.perform
          }.not_to raise_error

          records = getter.records
          count = getter.count

          expect(records).to all(be_a(User))
          expect(count).to eq User.count
        end
      end

      describe '#extract_associations_from_filter' do
        let(:resource) { Tree }

        before { init_scopes }

        context 'with a single filter as JSON string' do
          let(:filters) {
            {
              field: 'island:updated_at',
              operator: 'equal',
              value: '2024-01-01'
            }.to_json
          }

          it 'extracts the correct association' do
            expect(getter.send(:extract_associations_from_filter)).to eq [:island]
          end
        end

        context 'with grouped conditions as JSON string' do
          let(:filters) {
            {
              aggregator: 'and',
              conditions: [
                { field: 'island:updated_at', operator: 'equal', value: '2024-01-01' },
                { field: 'owner:name', operator: 'equal', value: 'Michel' },
                { field: 'id', operator: 'present', value: nil }
              ]
            }.to_json
          }

          it 'extracts all unique associations' do
            expect(getter.send(:extract_associations_from_filter)).to match_array [:island, :owner]
          end
        end

        context 'when filters has no association field' do
          let(:filters) {
            {
              field: 'id',
              operator: 'equal',
              value: 1
            }.to_json
          }

          it 'returns an empty array' do
            expect(getter.send(:extract_associations_from_filter)).to eq []
          end
        end

        context 'when filters is nil' do
          let(:filters) { nil }

          it 'returns an empty array' do
            expect(getter.send(:extract_associations_from_filter)).to eq []
          end
        end
      end
    end

    describe 'when searching with extended search' do
      let(:resource) { Tree }
      let(:search) { 'skull' }
      let(:searchExtended) { '1' }
      let(:requested_fields) { nil }

      # HashWithIndifferentAccess: the code reads @params['searchExtended'] (string),
      # as the controller hands it an ActionController::Parameters.
      let(:search_params) {
        ActiveSupport::HashWithIndifferentAccess.new(
          page: { size: pageSize, number: pageNumber },
          search: search,
          searchExtended: searchExtended,
          fields: requested_fields,
          timezone: 'Europe/Paris',
        )
      }

      # NOTICE: the count route builds a getter and calls #count on it without ever
      #         calling #perform, so the list getter has to be a separate instance —
      #         #perform rewrites @records with the eager loads and would hide the defect.
      let(:getter) { described_class.new(resource, search_params, user) }
      let(:list_getter) { described_class.new(resource, search_params, user) }

      # NOTICE: `Lemon Tree` and `Ginger Tree` both grow on the island `Skull`, and no
      #         tree carries `skull` in its own name — so extended search matches 2
      #         records where plain search matches none.
      describe 'when no fields are requested' do
        it 'counts the records the list returns instead of failing on the un-joined association' do
          list_getter.perform

          expect(getter.count).to eq 2
          expect(list_getter.records.count).to eq 2
        end

        it 'keeps every one-association in the include set when no fields are requested' do
          expect(getter.includes).to contain_exactly(:owner, :cutter, :island, :eponymous_island, :location)
        end
      end

      describe 'when fields are requested' do
        let(:requested_fields) { { 'Tree' => 'id,name' } }

        it 'counts the same records as the request carrying no fields' do
          list_getter.perform

          expect(getter.count).to eq 2
          expect(list_getter.records.count).to eq 2
        end

        it 'keeps the same include set when fields are requested' do
          expect(getter.includes).to contain_exactly(:owner, :cutter, :island, :eponymous_island, :location)
        end
      end

      describe 'when extended search is off' do
        let(:searchExtended) { '0' }

        it 'matches on the own columns only and counts none of the associated records' do
          list_getter.perform

          expect(getter.count).to eq 0
          expect(list_getter.records.count).to eq 0
          expect(getter.includes).to eq []
        end
      end

      describe 'when the search is nil' do
        let(:search) { nil }

        it 'counts every record' do
          list_getter.perform

          expect(getter.count).to eq 5
          expect(list_getter.records.count).to eq 5
        end
      end

      # NOTICE: Island's one-associations are `location` and the instance-dependent
      #         `eponymous_tree`. Nothing else joins `trees`, so a predicate naming it
      #         has no FROM entry — the shape `Tree` hides, since `eponymous_island`
      #         resolves against the `isle` join `island` already contributes.
      describe 'when a one-association carries an instance-dependent scope' do
        let(:resource) { Island }
        let(:search) { 'skull' }

        it 'searches the own columns without failing on the un-joined association' do
          list_getter.perform

          expect(getter.count).to eq 1
          expect(list_getter.records.count).to eq 1
        end

        describe 'when the search matches through an association the eager load does join' do
          let(:search) { '12345' }

          it 'still matches through that association' do
            list_getter.perform

            expect(getter.count).to eq 1
            expect(list_getter.records.count).to eq 1
          end
        end
      end
    end
  end
end