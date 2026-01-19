require 'rails_helper'

module ForestLiana
  describe 'Composite Primary Keys Support' do
    let(:rendering_id) { 13 }
    let(:user) { { 'id' => '1', 'rendering_id' => rendering_id } }
    let(:scopes) { { 'scopes' => {}, 'team' => { 'id' => '1', 'name' => 'Operations' } } }

    before do
      ForestLiana::ScopeManager.invalidate_scope_cache(rendering_id)
      allow(ForestLiana::ScopeManager).to receive(:fetch_scopes).and_return(scopes)
    end

    describe ResourceUpdater do
      describe 'with composite primary key' do
        it 'correctly parses composite ID in JSON format' do
          expect(ForestLiana::Utils::CompositePrimaryKeyHelper.parse_composite_id('[1,2]')).to eq([1, 2])
          expect(ForestLiana::Utils::CompositePrimaryKeyHelper.parse_composite_id('[10,20]')).to eq([10, 20])
          expect(ForestLiana::Utils::CompositePrimaryKeyHelper.parse_composite_id('["a","b"]')).to eq(['a', 'b'])
        end

        it 'raises error for invalid composite ID format' do
          expect {
            ForestLiana::Utils::CompositePrimaryKeyHelper.parse_composite_id('invalid')
          }.to raise_error(ForestLiana::Errors::HTTP422Error)
        end

        it 'finds record using composite key conditions' do
          mock_resource = double('Resource', primary_key: [:user_id, :island_id])
          mock_scoped_records = double('ScopedRecords')
          mock_record = double('Record')

          allow(mock_scoped_records).to receive(:find_by)
            .with({ user_id: 1, island_id: 2 })
            .and_return(mock_record)

          result = ForestLiana::Utils::CompositePrimaryKeyHelper.find_record(
            mock_scoped_records,
            mock_resource,
            '[1,2]'
          )

          expect(result).to eq(mock_record)
          expect(mock_scoped_records).to have_received(:find_by).with({ user_id: 1, island_id: 2 })
        end

        it 'falls back to standard find for simple primary key' do
          mock_resource = double('Resource', primary_key: 'id')
          mock_scoped_records = double('ScopedRecords')
          mock_record = double('Record')

          allow(mock_scoped_records).to receive(:find).with(123).and_return(mock_record)

          result = ForestLiana::Utils::CompositePrimaryKeyHelper.find_record(
            mock_scoped_records,
            mock_resource,
            123
          )

          expect(result).to eq(mock_record)
          expect(mock_scoped_records).to have_received(:find).with(123)
        end
      end
    end

    describe HasManyGetter do
      describe '#count with composite primary key' do
        let(:composite_association_class) do
          mock_class = double('CompositeModel')
          allow(mock_class).to receive(:primary_key).and_return([:user_id, :island_id])
          allow(mock_class).to receive(:table_name).and_return('user_islands')
          allow(mock_class).to receive(:connection).and_return(double('Connection', adapter_name: adapter_name))
          mock_class
        end

        let(:mock_records) { double('Records') }

        before do
          allow(mock_records).to receive(:distinct).and_return(mock_records)
          allow(mock_records).to receive(:count).and_return(5)
        end

        context 'with PostgreSQL adapter' do
          let(:adapter_name) { 'PostgreSQL' }

          it 'uses ROW() syntax for COUNT DISTINCT' do
            getter = HasManyGetter.allocate
            getter.instance_variable_set(:@records, mock_records)

            allow(getter).to receive(:model_association).and_return(composite_association_class)

            getter.count

            expect(mock_records).to have_received(:count) do |arg|
              expect(arg.to_s).to include('ROW(')
              expect(arg.to_s).to include('user_islands.user_id')
              expect(arg.to_s).to include('user_islands.island_id')
            end
          end
        end

        context 'with MySQL adapter' do
          let(:adapter_name) { 'Mysql2' }

          it 'uses standard multi-column syntax for COUNT DISTINCT' do
            getter = HasManyGetter.allocate
            getter.instance_variable_set(:@records, mock_records)

            allow(getter).to receive(:model_association).and_return(composite_association_class)

            getter.count

            expect(mock_records).to have_received(:count) do |arg|
              expect(arg.to_s).not_to include('ROW(')
              expect(arg.to_s).to include('user_islands.user_id, user_islands.island_id')
            end
          end
        end

        context 'with SQLite adapter' do
          let(:adapter_name) { 'SQLite' }

          it 'uses concatenation syntax for COUNT DISTINCT' do
            getter = HasManyGetter.allocate
            getter.instance_variable_set(:@records, mock_records)

            allow(getter).to receive(:model_association).and_return(composite_association_class)

            getter.count

            expect(mock_records).to have_received(:count) do |arg|
              expect(arg.to_s).to include("||")
              expect(arg.to_s).to include("'|'")
            end
          end
        end
      end
    end

    describe BelongsToUpdater do
      describe 'with composite primary key parent' do
        it 'uses CompositePrimaryKeyHelper to find the parent record' do
          composite_model = double('CompositeModel')
          association = double('Association', name: :user, klass: User)
          mock_record = double('Record', save: true)
          allow(mock_record).to receive(:user=)

          params = { id: '[1,2]', 'data' => { id: '5', type: 'User' } }

          allow(ForestLiana::Utils::CompositePrimaryKeyHelper).to receive(:find_record).and_return(mock_record)
          allow(User).to receive(:find).and_return(double('User'))
          allow(SchemaUtils).to receive(:polymorphic?).and_return(false)

          updater = described_class.new(composite_model, association, params)
          updater.perform

          expect(ForestLiana::Utils::CompositePrimaryKeyHelper).to have_received(:find_record)
            .with(composite_model, composite_model, '[1,2]')
        end
      end
    end

    describe HasManyAssociator do
      describe 'with composite primary key parent' do
        it 'uses CompositePrimaryKeyHelper to find the parent record' do
          composite_model = double('CompositeModel')
          association = double('Association', name: :trees, klass: Tree)
          mock_record = double('Record')
          mock_associated_records = double('AssociatedRecords')

          allow(mock_record).to receive(:send).with(:trees).and_return(mock_associated_records)
          allow(mock_associated_records).to receive(:<<)

          params = { id: '[1,2]', 'data' => [{ id: '5' }] }

          allow(ForestLiana::Utils::CompositePrimaryKeyHelper).to receive(:find_record).and_return(mock_record)
          allow(Tree).to receive(:find).and_return(double('Tree'))

          associator = described_class.new(composite_model, association, params)
          associator.perform

          expect(ForestLiana::Utils::CompositePrimaryKeyHelper).to have_received(:find_record)
            .with(composite_model, composite_model, '[1,2]')
        end
      end
    end

    describe HasManyDissociator do
      describe 'with composite primary key parent' do
        it 'uses CompositePrimaryKeyHelper to find the parent record' do
          composite_model = double('CompositeModel')
          association = double('Association', name: :trees, klass: Tree, macro: :has_many)
          mock_record = double('Record')
          mock_associated_records = double('AssociatedRecords')

          allow(mock_record).to receive(:send).with(:trees).and_return(mock_associated_records)
          allow(mock_associated_records).to receive(:delete)

          params = { id: '[1,2]', 'data' => [{ id: '5' }], delete: 'false' }
          forest_user = user

          allow(ForestLiana::Utils::CompositePrimaryKeyHelper).to receive(:find_record).and_return(mock_record)
          allow(Tree).to receive(:find).and_return(double('Tree'))

          dissociator = described_class.new(composite_model, association, params, forest_user)
          dissociator.perform

          expect(ForestLiana::Utils::CompositePrimaryKeyHelper).to have_received(:find_record)
            .with(composite_model, composite_model, '[1,2]')
        end
      end
    end
  end
end
