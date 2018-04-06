module ForestLiana
  class PieStatGetterTest < ActiveSupport::TestCase
    test 'Pie stat getter with an aggregate on a boolean field' do
      stat = PieStatGetter.new(BooleanField, {
        type: "Pie",
        collection: "boolean_field",
        timezone: "Europe/Paris",
        aggregate: "Count",
        group_by_field: "field"
      })

      stat.perform
      assert stat.record.value.count == 0
    end

    test 'Pie stat getter with an aggregate on a foreign key' do
      stat = PieStatGetter.new(BelongsToField, {
        type: "Pie",
        collection: "belongs_to_field",
        timezone: "Europe/Paris",
        aggregate: "Count",
        group_by_field: "has_one_field_id"
      })

      stat.perform
      assert stat.record.value.count == 30
    end
  end
end
