module ForestLiana
  class ValueStatGetterTest < ActiveSupport::TestCase
    rendering_id = 13
    user = { 'rendering_id' => rendering_id }

    describe 'with empty scopes' do
      # Mock empty scopes
      before do
        ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
        WebMock.stub_request(:get, "https://api.forestadmin.com/liana/scopes?renderingId=#{rendering_id}")
          .to_return(status: 200, body: '{}', headers: {})
      end

      describe 'with a simple filter' do
        it 'should have a countCurrent of 0' do
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
          }, user)

          stat.perform
          assert stat.record.value[:countCurrent] == 0
        end
      end

      describe 'with a filter on a belongs_to integer field' do
        it 'should have a countCurrent of 1' do
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
          }, user)

          stat.perform
          assert stat.record.value[:countCurrent] == 1
        end
      end

      describe 'with a filter on a belongs_to boolean field' do
        it 'should have a countCurrent of 0' do
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
          }, user)

          stat.perform
          assert stat.record.value[:countCurrent] == 0
        end
      end

      describe 'with a filter on a belongs_to enum field' do
        it 'should have a countCurrent of 1' do
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
          }, user)

          stat.perform
          assert stat.record.value[:countCurrent] == 1
        end
      end
    end
  end
end
