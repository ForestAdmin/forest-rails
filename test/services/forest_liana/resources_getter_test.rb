module ForestLiana
  class ResourcesGetterTest < ActiveSupport::TestCase

    test 'StringField page 1 size 15' do
      getter = ResourcesGetter.new(StringField, {
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

    test 'on a model having a reserved name' do
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

    test 'StringField page 2 size 10' do
      getter = ResourcesGetter.new(StringField, {
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

    test 'StringField sort by field' do
      getter = ResourcesGetter.new(StringField, {
        page: { size: 10, number: 1 },
        sort: '-field',
        timezone: 'America/Nome'
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
        sort: 'has_one_field.id',
        timezone: 'America/Nome'
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
        sort: '-belongs_to_field.id',
        timezone: 'America/Nome'
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
        fields: { 'Tree' => 'id' },
        page: { size: 10, number: 1 },
        filters: {
          aggregator: 'and',
          conditions: [{
            field: 'created_at',
            operator: 'after',
            value: '2015-06-18 08:00:00',
          }, {
            field: 'owner:name',
            operator: 'equal',
            value: 'Arnaud Besnier'
          }]
        }.to_json,
        timezone: 'America/Nome'
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

    test 'Filter before x hours' do
      getter = ResourcesGetter.new(Tree, {
        fields: { 'Tree' => 'id' },
        page: { size: 10, number: 1 },
        filters: {
          field: 'created_at',
          operator: 'before_x_hours_ago',
          value: 3
        }.to_json,
        timezone: 'America/Nome'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 5
      assert count = 5
      assert records.first.id == 4
      assert records.first.name == 'Oak'
      assert records.first.owner.name == 'Arnaud Besnier'
    end

    test 'Filter after x hours' do
      getter = ResourcesGetter.new(Tree, {
        fields: { 'Tree' => 'id' },
        page: { size: 10, number: 1 },
        filters: {
          field: 'created_at',
          operator: 'after_x_hours_ago',
          value: 3
        }.to_json,
        timezone: 'America/Nome'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 3
      assert count = 3
    end

    test 'Sort on an ambiguous field name with a filter' do
      getter = ResourcesGetter.new(Tree, {
        fields: { 'Tree' => 'id' },
        page: { size: 10, number: 1 },
        sort: '-name',
        filters: {
          field: 'owner:name',
          operator: 'equal',
          value: 'Arnaud Besnier'
        }.to_json,
        timezone: 'America/Nome'
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
        filters: {
          field: 'updated_at',
          operator: 'previous_year'
        }.to_json,
        timezone: 'America/Nome'
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
        fields: { 'Tree' => 'id' },
        page: { size: 10, number: 1 },
        filters: {
          field: 'owner:updated_at',
          operator: 'previous_year'
        }.to_json,
        timezone: 'America/Nome'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 2
      assert count = 2
      assert records.first.id == 6
    end

    test 'Filter equal on an updated_at field of an associated collection' do
      getter = ResourcesGetter.new(Tree, {
        fields: { 'Tree' => 'id' },
        page: { size: 10, number: 1 },
        filters: {
          field: 'owner:updated_at',
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

    test 'Filter on a field of an associated collection that does not exist' do
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

    test 'Filter on a field that does not exists' do
      exception = assert_raises(ForestLiana::Errors::HTTP422Error) {
        ForestLiana::ResourcesGetter.new(Tree, {
          fields: { 'Tree' => 'id'},
          searchExtended: '0',
          timezone: 'Europe/Paris',
          filters: {
            field: 'content',
            operator: 'contains',
            value: '*c*'
          }.to_json,
          collection: 'Article'
        })
      }

      assert_equal("Field 'content' not found", exception.message)
    end

  end
end
