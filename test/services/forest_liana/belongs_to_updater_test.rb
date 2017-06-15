module ForestLiana
  class BelongsToUpdaterTest < ActiveSupport::TestCase

    collection = ForestLiana::Model::Collection.new({
      name: 'serialize_and_belongs_to_fields',
      fields: [{
        type: 'String',
        field: 'field'
      }]
    })

    ForestLiana.apimap << collection
    ForestLiana.models << SerializeField

    test 'Update a record on a "serialize" attribute with a missing value' do
      params = ActionController::Parameters.new(
        id: 1,
        data: {
          id: 1,
          type: "serialize_field",
          attributes: {}
        }
      )
      updater = BelongsToUpdater.new(SerializeField, params)
      updater.perform

      assert updater.record.valid?
      assert updater.record.field == []
    end
  end
end
