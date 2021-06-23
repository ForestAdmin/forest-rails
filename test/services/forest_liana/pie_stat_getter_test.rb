module ForestLiana
  class PieStatGetterTest < ActiveSupport::TestCase
    rendering_id = 13
    user = { 'rendering_id' => rendering_id }

    describe 'with empty scopes' do
      # Mock empty scopes
      before do
        ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
        WebMock.stub_request(:get, "https://api.forestadmin.com/liana/scopes?renderingId=#{rendering_id}")
          .to_return(status: 200, body: '{}', headers: {})
      end

      describe 'with an aggregate on a boolean field' do
        it 'should count 0 occurences' do
          stat = PieStatGetter.new(BooleanField, {
            type: "Pie",
            collection: "boolean_field",
            timezone: "Europe/Paris",
            aggregate: "Count",
            group_by_field: "field"
          }, user)

          stat.perform
          assert stat.record.value.count == 0
        end
      end

      describe 'with an aggregate on a foreign key' do
        it 'should count 30 occurences' do
          stat = PieStatGetter.new(BelongsToField, {
            type: "Pie",
            collection: "belongs_to_field",
            timezone: "Europe/Paris",
            aggregate: "Count",
            group_by_field: "has_one_field_id"
          }, user)

          stat.perform
          assert stat.record.value.count == 30
        end
      end
    end
  end
end
