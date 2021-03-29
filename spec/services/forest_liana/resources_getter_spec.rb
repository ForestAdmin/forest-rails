module ForestLiana
  describe ResourcesGetter do
    before(:each) do
      user1 = User.create(name: 'Michel')
      user2 = User.create(name: 'Robert')
      user3 = User.create(name: 'Vince')
      user4 = User.create(name: 'Sandro')
      user5 = User.create(name: 'Olesya')
      user6 = User.create(name: 'Romain')
      user7 = User.create(name: 'Valentin')
      user8 = User.create(name: 'Jason')
      user9 = User.create(name: 'Arnaud')
      user10 = User.create(name: 'Jeff')
      user11 = User.create(name: 'Steve')
      user12 = User.create(name: 'Marc')
      user13 = User.create(name: 'Xavier')
      user14 = User.create(name: 'Paul')
      user15 = User.create(name: 'Mickael')
      user16 = User.create(name: 'Mike')
      user17 = User.create(name: 'Maxime')
      user18 = User.create(name: 'Gertrude')
      user19 = User.create(name: 'Monique')
      user20 = User.create(name: 'Mia')
      user21 = User.create(name: 'Rachid')
      user22 = User.create(name: 'Edouard')
      user23 = User.create(name: 'Sacha')
      user24 = User.create(name: 'Caro')
      user25 = User.create(name: 'Amand')
      user26 = User.create(name: 'Nathan')
      user27 = User.create(name: 'Noémie')
      user28 = User.create(name: 'Robin')
      user29 = User.create(name: 'Gaelle')
      user30 = User.create(name: 'Isabelle')

      island1 = Island.create(name: 'Skull', updated_at: Time.now - 1.years)
      island2 = Island.create(name: 'Muerta', updated_at: Time.now - 5.years)
      island3 = Island.create(name: 'Treasure', updated_at: Time.now)
      island4 = Island.create(name: 'Birds', updated_at: Time.now - 7.years)
      island5 = Island.create(name: 'Lille', updated_at: Time.now - 1.years)

      tree1 = Tree.create(name: 'Lemon Tree', created_at: Time.now - 7.years, island: island1, owner: user1, cutter: user1)
      tree2 = Tree.create(name: 'Ginger Tree', created_at: Time.now - 7.years, island: island1, owner: user2, cutter: user1)
      tree3 = Tree.create(name: 'Apple Tree', created_at: Time.now - 5.years, island: island2, owner: user3, cutter: user1)
      tree4 = Tree.create(name: 'Pear Tree', created_at: Time.now + 4.hours, island: island4, owner: user4, cutter: user2)
      tree5 = Tree.create(name: 'Choco Tree', created_at: Time.now, island: island4, owner: user5, cutter: user2)

      location1 = Location.create(coordinates: '12345', island: island1)
      location2 = Location.create(coordinates: '54321', island: island2)
      location3 = Location.create(coordinates: '43215', island: island3)
      location4 = Location.create(coordinates: '21543', island: island4)
      location5 = Location.create(coordinates: '32154', island: island5)

      reference = Reference.create()
    end

    after(:each) do
      User.destroy_all
      Island.destroy_all
      Location.destroy_all
      Tree.destroy_all
    end

    describe 'when there are more records than the page size' do
      describe 'when asking for the 1st page and 15 records' do
        it 'should get only the expected records' do
          getter = ResourcesGetter.new(User, {
            page: { size: 15, number: 1 },
            sort: '-id',
            timezone: 'America/Nome'
          })
          getter.perform
          records = getter.records
          count = getter.count

          assert records.count == 15
          assert count = 30
          assert records.first.id == 30
          assert records.last.id == 16
        end
      end

      describe 'when asking for the 2nd page and 10 records' do
        it 'should get only the expected records' do
          getter = ResourcesGetter.new(User, {
            page: { size: 10, number: 2 },
            sort: '-id',
            timezone: 'America/Nome'
          })
          getter.perform
          records = getter.records
          count = getter.count

          assert records.count == 10
          assert count = 30
          assert records.first.id == 20
          assert records.last.id == 11
        end
      end
    end

    describe 'when on a model having a reserved SQL word as name' do
      it 'should get the ressource properly' do
        getter = ResourcesGetter.new(Reference, {
          page: { size: 10, number: 1 },
          sort: '-id',
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 1
        assert count = 1
        assert records.first.id == 1
      end
    end

    describe 'when sorting by a specific field' do
      it 'should get only the expected records' do
        getter = ResourcesGetter.new(User, {
          page: { size: 5, number: 1 },
          sort: '-name',
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 5
        assert count = 30
        assert records.map(&:name) == ['Xavier', 'Vince', 'Valentin', 'Steve', 'Sandro']
      end
    end

    describe 'when sorting by a belongs_to association' do
      it 'should get only the expected records' do
        getter = ResourcesGetter.new(Tree, {
          page: { size: 10, number: 1 },
          sort: 'owner.name',
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 5
        assert count = 5
        assert records.map(&:id) == [1, 5, 2, 4, 3]
      end
    end

    describe 'when sorting by a has_one association' do
      it 'should get only the expected records' do
        getter = ResourcesGetter.new(Island, {
          page: { size: 5, number: 1 },
          sort: 'location.coordinates',
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 5
        assert count = 5
        assert records.map(&:id) == [1, 4, 5, 3, 2]
      end
    end

    describe 'when filtering on an ambiguous field' do
      it 'should get only the expected records' do
        getter = ResourcesGetter.new(Tree, {
          fields: { 'Tree' => 'id' },
          page: { size: 5, number: 1 },
          filters: {
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
          }.to_json,
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 1
        assert count = 1
        assert records.first.id == 3
        assert records.first.name == 'Apple Tree'
        assert records.first.cutter.name == 'Michel'
      end
    end

    describe 'when filtering on before x hours ago' do
      it 'should filter as expected' do
        getter = ResourcesGetter.new(Tree, {
          fields: { 'Tree' => 'id' },
          page: { size: 10, number: 1 },
          filters: {
            field: 'created_at',
            operator: 'before_x_hours_ago',
            value: 3
          }.to_json,
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 3
        assert count = 3
        assert records.map(&:name) == ['Apple Tree', 'Ginger Tree', 'Lemon Tree']
      end
    end

    describe 'when filtering on after x hours ago' do
      it 'should filter as expected' do
        getter = ResourcesGetter.new(Tree, {
          fields: { 'Tree' => 'id' },
          page: { size: 10, number: 1 },
          filters: {
            field: 'created_at',
            operator: 'after_x_hours_ago',
            value: 3
          }.to_json,
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 2
        assert count = 2
        assert records.map(&:name) == ['Pear Tree', 'Choco Tree']
      end
    end

    describe 'when sorting on an ambiguous field name with a filter' do
      it 'should get only the sorted expected records' do
        getter = ResourcesGetter.new(Tree, {
          fields: { 'Tree' => 'id' },
          page: { size: 10, number: 1 },
          sort: '-name',
          filters: {
            field: 'cutter:name',
            operator: 'equal',
            value: 'Michel'
          }.to_json,
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 3
        assert count = 3
        assert records.map(&:name) == ['Lemon Tree', 'Ginger Tree', 'Apple Tree']
      end
    end

    describe 'when filtering on an updated_at field of the main collection' do
      it 'should get only the expected records' do
        getter = ResourcesGetter.new(Island, {
          page: { size: 10, number: 1 },
          filters: {
            field: 'updated_at',
            operator: 'previous_year'
          }.to_json,
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 2
        assert count = 2
        assert records.map(&:name) == ['Lille', 'Skull']
      end
    end

    describe 'when filtering on an updated_at field of an associated collection' do
      it 'should get only the expected records' do
        getter = ResourcesGetter.new(Tree, {
          fields: { 'Tree' => 'id' },
          page: { size: 10, number: 1 },
          filters: {
            field: 'island:updated_at',
            operator: 'previous_year'
          }.to_json,
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 2
        assert count = 2
        assert records.map(&:name) == ['Ginger Tree', 'Lemon Tree']
      end
    end

    describe 'when filtering on an exact updated_at field of an associated collection' do
      it 'should get only the expected records' do
        getter = ResourcesGetter.new(Tree, {
          fields: { 'Tree' => 'id' },
          page: { size: 10, number: 1 },
          filters: {
            field: 'island:updated_at',
            operator: 'equal',
            value: 'Sat Jul 02 2016 11:52:00 GMT-0400 (EDT)',
          }.to_json,
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 0
        assert count = 0
      end
    end

    describe 'when filtering on a field of an associated collection that does not exist' do
      it 'should raise the right error' do
        exception = assert_raises(ForestLiana::Errors::HTTP422Error) {
          ForestLiana::ResourcesGetter.new(Tree, {
            fields: { 'Tree' => 'id'},
            searchExtended: '0',
            timezone: 'Europe/Paris',
            filters: {
              field: 'leaf:id',
              operator: 'equal',
              value: 1
            }.to_json,
            collection: 'Tree'
          })
        }
        assert_equal("Association 'leaf' not found", exception.message)
      end
    end

    describe 'when filtering on a field that does not exists' do
      it 'should raise the right error' do
        exception = assert_raises(ForestLiana::Errors::HTTP422Error) {
          ForestLiana::ResourcesGetter.new(Tree, {
            fields: { 'Tree' => 'id'},
            searchExtended: '0',
            timezone: 'Europe/Paris',
            filters: {
              field: 'content',
              operator: 'contains',
              value: 'c'
            }.to_json,
            collection: 'Article'
          })
        }

        assert_equal("Field 'content' not found", exception.message)
      end
    end

    describe 'when filtering on a smart field' do
      it 'should filter as expected' do
        getter = ResourcesGetter.new(User, {
          fields: { 'User' => 'id' },
          page: { size: 10, number: 1 },
          filters: {
            field: 'cap_name',
            operator: 'equal',
            value: 'MICHEL',
          }.to_json,
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 1
        assert count = 1
        assert records.first.id == 1
        assert records.first.name == 'Michel'
      end
    end

    describe 'when filtering on a smart field with no filter method' do
      it 'should raise the right error' do
        exception = assert_raises(ForestLiana::Errors::NotImplementedMethodError) {
          ForestLiana::ResourcesGetter.new(Location, {
            fields: { 'Location' => 'id'},
            searchExtended: '0',
            timezone: 'Europe/Paris',
            filters: {
              field: 'alter_coordinates',
              operator: 'equal',
              value: '12345XYZ',
            }.to_json,
          })
        }

        assert_equal("method filter on smart field 'alter_coordinates' not found", exception.message)
      end
    end
  end
end
