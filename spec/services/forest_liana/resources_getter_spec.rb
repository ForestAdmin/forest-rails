module ForestLiana
  class ResourcesGetterTest
    describe 'Filter on a smart field' do
      it 'should ...' do
        getter = ResourcesGetter.new(User, {
          fields: { 'Owner' => 'id' },
          page: { size: 10, number: 1 },
          filters: {
            field: 'cap_name',
            operator: 'is',
            value: 'SANDRO MUNDA',
          }.to_json,
          timezone: 'America/Nome'
        })
        getter.perform
        records = getter.records
        count = getter.count

        assert records.count == 1
        assert count = 1
        assert records.first.id == 1
        assert records.first.name == 'Sandro Munda'
      end
    end


  end
end
