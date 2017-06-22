module ForestLiana
  class ResourceUpdaterTest < ActiveSupport::TestCase

    collection = ForestLiana::Model::Collection.new({
      name: 'serialize_fields',
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
      updater = ResourceUpdater.new(SerializeField, params)
      updater.perform

      assert updater.record.valid?
      assert updater.record.field == "value 1"
    end

    test 'Update a record on a "serialize" attribute with a null value' do
      params = ActionController::Parameters.new(
        id: 1,
        data: {
          id: 1,
          type: "serialize_field",
          attributes: {
            field: nil
          }
        }
      )
      updater = ResourceUpdater.new(SerializeField, params)
      updater.perform

      assert updater.record.valid?
      byebug
      assert updater.record.field == []
    end

    test 'Update a record on a "serialize" attribute with a bad format value' do
      params = ActionController::Parameters.new(
        id: 1,
        data: {
          id: 1,
          type: "serialize_field",
          attributes: {
            field: "Lucas"
          }
        }
      )
      updater = ResourceUpdater.new(SerializeField, params)
      updater.perform

      assert updater.record.valid?
      assert updater.record.field == "value 1"
      assert updater.errors[0][:detail] == "Bad format for 'field' attribute value."
    end

    test 'Update a record on a "serialize" attribute with a well formated value' do
      params = ActionController::Parameters.new(
        id: 1,
        data: {
          id: 1,
          type: "serialize_field",
          attributes: {
            field: "[\"test\", \"test\"]"
          }
        }
      )
      updater = ResourceUpdater.new(SerializeField, params)
      updater.perform

      assert updater.record.valid?
      assert updater.record.field == ["test", "test"]
    end
  end
end
