module ForestLiana
  class HasManyGetterTest < ActiveSupport::TestCase
    collectionOwner = ForestLiana::Model::Collection.new({
      name: 'Owner',
      fields: []
    })

    collectionTree = ForestLiana::Model::Collection.new({
      name: 'Tree',
      fields: []
    })
    rendering_id = 13
    user = { 'rendering_id' => rendering_id }

    ForestLiana.apimap << collectionOwner
    ForestLiana.apimap << collectionTree
    ForestLiana.models << Owner
    ForestLiana.models << Tree

    describe 'with empty scopes' do
      # Mock empty scopes
      before do
        ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
        WebMock.stub_request(:get, "https://api.forestadmin.com/liana/scopes?renderingId=#{rendering_id}")
          .to_return(status: 200, body: '{}', headers: {})
      end

      describe 'with page 1 size 15' do
        it 'should return the 3 trees matching user 1' do
          association = Owner.reflect_on_association(:trees)

          getter = HasManyGetter.new(Owner, association, {
            id: 1,
            association_name: 'trees',
            page: { size: 15, number: 1 },
            timezone: 'America/Nome'
          }, user)
          getter.perform
          records = getter.records
          count = getter.count

          assert records.count == 3
          assert count = 3
          assert records.first.id == 7
        end
      end

      describe 'when sorting by decreasing id' do
        it 'should put the 8th id first' do
          association = Owner.reflect_on_association(:trees)

          getter = HasManyGetter.new(Owner, association, {
            id: 1,
            association_name: 'trees',
            sort: '-id',
            page: { size: 15, number: 1 },
            timezone: 'America/Nome'
          }, user)
          getter.perform
          records = getter.records
          count = getter.count

          assert records.count == 3
          assert count = 3
          assert records.first.id == 8
        end
      end

      describe 'when searching for Fir' do
        it 'should retunr only Fir' do
          association = Owner.reflect_on_association(:trees)

          getter = HasManyGetter.new(Owner, association, {
            id: 1,
            association_name: 'trees',
            search: 'Fir',
            page: { size: 15, number: 1 },
            timezone: 'America/Nome'
          }, user)
          getter.perform
          records = getter.records
          count = getter.count

          assert records.count == 1
          assert count = 1
          assert records.first.id == 8
        end
      end
    end

    describe 'with scopes' do
      # Mock empty scopes
      before do
        ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
        collection_scope = {
          'scope'=> {
            'filter'=> {
              'aggregator' => 'and',
              'conditions' => [
                { 'field' => 'name', 'operator' => 'contains', 'value' => 'i' }
              ]
            },
            'dynamicScopesValues' => { }
          }
        }
        api_scopes = JSON.generate({ 'Tree' => collection_scope })
        WebMock.stub_request(:get, "https://api.forestadmin.com/liana/scopes?renderingId=13")
          .to_return(status: 200, body: api_scopes, headers: {})
      end

      describe 'when asking for all trees' do
        it 'should return trees belonging to user 1 and matching the scopes' do
          association = Owner.reflect_on_association(:trees)

          getter = HasManyGetter.new(Owner, association, {
            id: 1,
            association_name: 'trees',
            timezone: 'America/Nome'
          }, user)
          getter.perform
          records = getter.records
          count = getter.count

          # only sequoia and fir contains an `i`
          assert records.count == 2
          assert count = 2
          assert records.first.id == 7
        end
      end
    end
  end
end
