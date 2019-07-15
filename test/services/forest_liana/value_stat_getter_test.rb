module ForestLiana
  class ValueStatGetterTest < ActiveSupport::TestCase
    test 'Value stat getter with a simple filter' do
      stat = ValueStatGetter.new(BooleanField, {
        type: "Value",
        collection: "boolean_field",
        timezone: "Europe/Paris",
        aggregate: "Count",
        filters: {
          field: "field",
          operator: 'equal',
          value: "true"
        }.to_json
      })

      stat.perform
      assert stat.record.value[:countCurrent] == 0
    end

    test 'Value stat getter with a filter on a belongs_to integer field' do
      stat = ValueStatGetter.new(BelongsToField, {
        type: "Value",
        collection: "belongs_to_field",
        timezone: "Europe/Paris",
        aggregate: "Count",
        filters: {
          field: "has_one_field:id",
          operator: 'equal',
          value: 3
        }.to_json
      })

      stat.perform
      assert stat.record.value[:countCurrent] == 1
    end

    test 'Value stat getter with a filter on a belongs_to boolean field' do
      stat = ValueStatGetter.new(BelongsToField, {
        type: "Value",
        collection: "belongs_to_field",
        timezone: "Europe/Paris",
        aggregate: "Count",
        filters: {
          field: "has_one_field:checked",
          operator: 'equal',
          value: "false"
        }.to_json
      })

      stat.perform
      assert stat.record.value[:countCurrent] == 0
    end

    test 'Value stat getter with a filter on a belongs_to enum field' do
      stat = ValueStatGetter.new(BelongsToField, {
        type: "Value",
        collection: "belongs_to_field",
        timezone: "Europe/Paris",
        aggregate: "Count",
        filters: {
          field: "has_one_field:status",
          operator: 'equal',
          value: "pending"
        }.to_json
      })

      stat.perform
      assert stat.record.value[:countCurrent] == 1
    end
  end
end
