require 'rails_helper'

module ForestLiana
  describe ResourcesGetter do
    describe 'composite primary keys support' do
      let(:resource) { User }
      let(:params) do
        {
          page: { size: 10, number: 1 },
          sort: 'id',
          fields: { 'User' => 'id,name' }
        }
      end
      let(:user) { { 'id' => '1', 'rendering_id' => 13 } }

      before do
        allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return({
          'scopes' => {},
          'team' => {'id' => '1', 'name' => 'Operations'}
        })
      end

      describe '#get_one_association' do
        it 'does not crash when name is a symbol' do
          getter = described_class.new(resource, params, user)
          expect {
            getter.send(:get_one_association, :owner)
          }.not_to raise_error
        end

        it 'does not crash when name is a string' do
          getter = described_class.new(resource, params, user)
          expect {
            getter.send(:get_one_association, 'owner')
          }.not_to raise_error
        end

        it 'does not crash when name is an array (composite key edge case)' do
          getter = described_class.new(resource, params, user)
          # Should not raise "undefined method `to_sym' for Array"
          expect {
            getter.send(:get_one_association, [:user_id, :slot_id])
          }.not_to raise_error
        end

        it 'returns nil gracefully when name is an array' do
          getter = described_class.new(resource, params, user)
          result = getter.send(:get_one_association, [:user_id, :slot_id])
          expect(result).to be_nil
        end
      end

      describe 'handling composite foreign keys in associations' do
        let(:mock_association) do
          double('Association',
            name: :test_association,
            foreign_key: [:user_id, :slot_id],  # Composite foreign key
            klass: double('Klass', column_names: ['id', 'name']),
            macro: :has_one,
            options: {}
          )
        end

        let(:simple_association) do
          double('Association',
            name: :simple_association,
            foreign_key: 'user_id',  # Simple foreign key
            klass: double('Klass', column_names: ['id', 'name']),
            macro: :has_one,
            options: {}
          )
        end

        describe '#columns_for_cross_database_association' do
          it 'handles composite foreign keys without crashing' do
            getter = described_class.new(resource, params, user)

            allow(resource).to receive(:reflect_on_association)
              .with(:test_association)
              .and_return(mock_association)

            expect {
              getter.send(:columns_for_cross_database_association, :test_association)
            }.not_to raise_error
          end

          it 'includes all composite foreign key columns' do
            getter = described_class.new(resource, params, user)

            allow(resource).to receive(:reflect_on_association)
              .with(:test_association)
              .and_return(mock_association)

            columns = getter.send(:columns_for_cross_database_association, :test_association)

            expect(columns).to include(:user_id)
            expect(columns).to include(:slot_id)
          end

          it 'handles simple foreign keys without breaking existing behavior' do
            getter = described_class.new(resource, params, user)

            allow(resource).to receive(:reflect_on_association)
              .with(:simple_association)
              .and_return(simple_association)

            expect {
              columns = getter.send(:columns_for_cross_database_association, :simple_association)
              expect(columns).to include(:user_id)
            }.not_to raise_error
          end
        end
      end
    end
  end
end
