module ForestLiana
  class ValueStatGetterTest < ActiveSupport::TestCase
    test 'Value stat getter with a simple filter' do
      stat = ValueStatGetter.new(BooleanField, {
        type: "Value",
        collection: "boolean_field",
        timezone: "+02:00",
        aggregate: "Count",
        filterType: "and",
        filters: [{
          field: "field",
          value: "true"
        }]
      })

      stat.perform
      assert stat.record.value[:countCurrent] == 0
    end

    test 'Value stat getter with a filter on a belongs_to field' do
      stat = ValueStatGetter.new(BelongsToField, {
        type: "Value",
        collection: "belongs_to_field",
        timezone: "+02:00",
        aggregate: "Count",
        filterType: "and",
        filters: [{
          field: "has_one_field:id",
          value: "3"
        }]
      })

      stat.perform
      assert stat.record.value[:countCurrent] == 1
    end
  end
end
