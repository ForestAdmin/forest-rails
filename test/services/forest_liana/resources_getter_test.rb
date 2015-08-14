module ForestLiana
  class ResourcesGetterTest < ActiveSupport::TestCase

    test 'StringField page 1 size 15' do
      getter = ResourcesGetter.new(StringField, {
        page: { size: 15, number: 1 }
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
        page: { size: 10, number: 2 }
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

    test 'Sort by a has_many association' do
      getter = ResourcesGetter.new(HasManyField, {
        page: { size: 10, number: 1 },
        sort: '-belongs_to_field'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 10
      assert count = 30
      assert records.first.id = 7
    end

  end
end
