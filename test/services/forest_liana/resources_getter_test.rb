module ForestLiana
  class ResourcesGetterTest < ActiveSupport::TestCase

    test 'StringField page 1 size 15' do
      getter = ResourcesGetter.new(StringField, {
        page: { size: 15, number: 1 },
        sort: '-id'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 15
      assert count = 30
      assert records.first.id == 30
      assert records.last.id == 16
    end

    test 'StringField page 2 size 10' do
      getter = ResourcesGetter.new(StringField, {
        page: { size: 10, number: 2 },
        sort: '-id'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 10
      assert count = 30
      assert records.first.id == 20
      assert records.last.id == 11
    end

    test 'StringField sort by field' do
      getter = ResourcesGetter.new(StringField, {
        page: { size: 10, number: 1 },
        sort: '-field'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 10
      assert count = 30
      assert records.map(&:field) == ['Test 9', 'Test 8', 'Test 7', 'Test 6',
                                     'Test 5', 'Test 4', 'Test 30', 'Test 3',
                                     'Test 29', 'Test 28']
    end

    test 'Sort by a belongs_to association' do
      getter = ResourcesGetter.new(BelongsToField, {
        page: { size: 10, number: 1 },
        sort: 'has_one_field.id'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 10
      assert count = 30
      assert records.first.has_one_field_id == 1
      assert records.last.has_one_field_id == 10
    end

    test 'Sort by a has_one association' do
      getter = ResourcesGetter.new(HasOneField, {
        page: { size: 10, number: 1 },
        sort: '-belongs_to_field.id'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 10
      assert count = 30
      assert records.first.belongs_to_field.id == 30
      assert records.last.belongs_to_field.id == 21
    end

    test 'Filter on ambiguous field' do
      getter = ResourcesGetter.new(Tree, {
        page: { size: 10, number: 1 },
        filter: {
          'created_at' => '>2015-06-18 08:00:00',
          'owner:name' => 'Arnaud Besnier'
        },
        filterType: 'and'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 1
      assert count = 1
      assert records.first.id == 4
      assert records.first.name == 'Oak'
      assert records.first.owner.name == 'Arnaud Besnier'
    end

    test 'Sort on an ambiguous field name with a filter' do
      getter = ResourcesGetter.new(Tree, {
        page: { size: 10, number: 1 },
        sort: '-name',
        filter: { 'owner:name' => 'Arnaud Besnier' }
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 3
      assert count = 3
      assert records.first.name == 'Oak'
      assert records.last.name == 'Mapple'
    end

    test 'Filter on an updated_at field of the main collection' do
      getter = ResourcesGetter.new(Owner, {
        page: { size: 10, number: 1 },
        filter: { 'updated_at' => '$previousYear' },
        filterType: 'and'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 1
      assert count = 1
      assert records.first.id == 3
    end

    test 'Filter on an updated_at field of an associated collection' do
      getter = ResourcesGetter.new(Tree, {
        page: { size: 10, number: 1 },
        filter: { 'owner:updated_at' => '$previousYear' },
        filterType: 'and'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 1
      assert count = 1
      assert records.first.id == 5
    end

    test 'Filter equal on an updated_at field of an associated collection' do
      getter = ResourcesGetter.new(Tree, {
        page: { size: 10, number: 1 },
        filter: {
          'owner:updated_at' => 'Sat Jul 02 2016 11:52:00 GMT-0400 (EDT)',
        }
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 0
      assert count = 0
    end
  end
end
