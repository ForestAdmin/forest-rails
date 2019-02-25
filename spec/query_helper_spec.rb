module ForestLiana
  describe QueryHelper do
    before(:all) do
      Tree.connection
      Owner.connection
    end

    describe 'get_one_associations' do
      context 'on a model having a hasMany association' do
        it 'should not return any one-one associations' do
          associations = QueryHelper.get_one_associations(Owner)
          expect(associations.length).to eq(0)
        end
      end

      context 'on a model having a belongsTo association' do
        it 'should return the one-one associations' do
          associations = QueryHelper.get_one_associations(Tree)
          expect(associations.length).to eq(1)
          expect(associations.first.name).to eq(:owner)
          expect(associations.first.klass).to eq(Owner)
        end
      end
    end

    describe 'get_one_association_names_symbol' do
      it 'should return the one-one associations names as symbols' do
        expect(QueryHelper.get_one_association_names_symbol(Tree)).to eq([:owner])
      end
    end

    describe 'get_one_association_names_string' do
      it 'should return the one-one associations names as strings' do
        expect(QueryHelper.get_one_association_names_string(Tree)).to eq(['owner'])
      end
    end
  end
end
