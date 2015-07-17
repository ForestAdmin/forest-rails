require 'test_helper'
module Forest
  class ResourceDeserializerTest < ActiveSupport::TestCase
    test 'JSONAPI payload should extract attributes' do
      json = { data: { type: 'users', attributes: { name: 'forest' }}}.as_json
      params = ActionController::Parameters.new(json)
      result = ResourceDeserializer.new(params).perform

      assert result.length == 1
      assert result[:name] = 'forest'
    end

    test 'JSONAPI payload should support relationships' do
      json = {
        data: {
          type: 'users',
          attributes: {
            name: 'forest'
          },
          relationships: {
            organization: {
              data: {
                type: 'organizations',
                id: '42'
              }
            }
          }
        }
      }.as_json
      params = ActionController::Parameters.new(json)
      result = ResourceDeserializer.new(params).perform

      assert result.length == 2
      assert result[:name] = 'forest'
      assert result[:organization_id] = '42'
    end

  end
end

