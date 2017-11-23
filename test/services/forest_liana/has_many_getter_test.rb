module ForestLiana
  class ResourcesGetterTest < ActiveSupport::TestCase

    collectionOwner = ForestLiana::Model::Collection.new({
      name: 'Owner',
      fields: []
    })

    collectionTree = ForestLiana::Model::Collection.new({
      name: 'Tree',
      fields: []
    })

    ForestLiana.apimap << collectionOwner
    ForestLiana.apimap << collectionTree
    ForestLiana.models << Owner
    ForestLiana.models << Tree

    test 'HasMany Getter page 1 size 15' do
      association = Owner.reflect_on_association(:trees)

      getter = HasManyGetter.new(Owner, association, {
        id: 1,
        association_name: 'trees',
        page: { size: 15, number: 1 },
        timezone: '-08:00'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 3
      assert count = 3
      assert records.first.id == 1
    end

    test 'HasMany Getter with sort parameter' do
      association = Owner.reflect_on_association(:trees)

      getter = HasManyGetter.new(Owner, association, {
        id: 1,
        association_name: 'trees',
        sort: '-id',
        page: { size: 15, number: 1 },
        timezone: '-08:00'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 3
      assert count = 3
      assert records.first.id == 8
    end

    test 'HasMany Getter with search parameter' do
      association = Owner.reflect_on_association(:trees)

      getter = HasManyGetter.new(Owner, association, {
        id: 1,
        association_name: 'trees',
        search: 'Fir',
        page: { size: 15, number: 1 },
        timezone: '-08:00'
      })
      getter.perform
      records = getter.records
      count = getter.count

      assert records.count == 1
      assert count = 1
      assert records.first.id == 8
    end
  end
end
