require 'minitest/mock'

module ForestLiana
  class ResourceCreatorTest < ActiveSupport::TestCase

    collection = ForestLiana::Model::Collection.new({
      name: 'SerializeField',
      fields: [{
        type: 'String',
        field: 'field'
      }]
    })

    ForestLiana.apimap << collection
    ForestLiana.models << SerializeField

    test 'Create a record on a "serialize" attribute with a well formatted value without strong params' do
      params = ActionController::Parameters.new(
        data: {
          type: "SerializeField",
          attributes: {
            field: "[\"test\", \"test\"]"
          }
        }
      )
      
      creator = ResourceCreator.new(SerializeField, params)
      creator.stub :has_strong_parameter, false do
        creator.perform

        assert creator.record.valid?
        assert creator.record.field == ["test", "test"]
      end
    end
  end
end
