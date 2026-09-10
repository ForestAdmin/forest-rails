module ForestLiana
  module Model
    describe Collection do
      def computed_field(name, dependencies_declared:, deps: [])
        field = { field: name, is_virtual: true, reference: nil, integration: nil }
        field[:dependencies] = deps if dependencies_declared
        field
      end

      def smart_relation(name)
        { field: name, is_virtual: true, reference: 'Other.id', integration: nil }
      end

      describe '#computed_smart_fields' do
        it 'excludes a smart relation (reference set) and an integration field' do
          collection = described_class.new(name: 'Tree', fields: [
            computed_field(:cap_name, dependencies_declared: true, deps: ['name']),
            smart_relation(:owner),
            { field: :external, is_virtual: true, reference: nil, integration: 'stripe' }
          ])

          expect(collection.computed_smart_fields.map { |f| f[:field] }).to eq([:cap_name])
        end
      end

      describe '#smart_field_dependencies_declared?' do
        it 'is true when every computed smart field declares, empty collection included' do
          collection = described_class.new(name: 'Tree', fields: [
            computed_field(:cap_name, dependencies_declared: true, deps: ['name'])
          ])

          expect(collection.smart_field_dependencies_declared?).to be true
        end

        it 'is false as soon as one computed smart field does not declare, even if unrelated to what is requested' do
          collection = described_class.new(name: 'Tree', fields: [
            computed_field(:cap_name, dependencies_declared: true, deps: ['name']),
            computed_field(:other, dependencies_declared: false)
          ])

          expect(collection.smart_field_dependencies_declared?).to be false
        end
      end

      describe '#smart_fields_projectable?' do
        let(:declared_collection) do
          described_class.new(name: 'Tree', fields: [computed_field(:cap_name, dependencies_declared: true, deps: ['name'])])
        end

        let(:mixed_collection) do
          described_class.new(name: 'Tree', fields: [
            computed_field(:cap_name, dependencies_declared: true, deps: ['name']),
            computed_field(:other, dependencies_declared: false)
          ])
        end

        it 'is true for a fully-declared collection, whatever is requested' do
          expect(declared_collection.smart_fields_projectable?(['cap_name'])).to be true
          expect(declared_collection.smart_fields_projectable?([])).to be true
        end

        it 'is false for a collection with any undeclared computed smart field, even when the request never names it' do
          expect(mixed_collection.smart_fields_projectable?(['cap_name'])).to be false
          expect(mixed_collection.smart_fields_projectable?([])).to be false
        end
      end

      describe '#smart_field_dependency_columns' do
        it 'unions the bare-column dependencies of the requested smart fields, dropping relation paths' do
          collection = described_class.new(name: 'Tree', fields: [
            computed_field(:cap_name, dependencies_declared: true, deps: %w[name island:name]),
            computed_field(:other, dependencies_declared: true, deps: ['age'])
          ])

          expect(collection.smart_field_dependency_columns(['cap_name'])).to eq(['name'])
        end

        it 'ignores a smart field that was not requested' do
          collection = described_class.new(name: 'Tree', fields: [
            computed_field(:cap_name, dependencies_declared: true, deps: ['name']),
            computed_field(:other, dependencies_declared: true, deps: ['age'])
          ])

          expect(collection.smart_field_dependency_columns(['cap_name'])).to eq(['name'])
        end
      end
    end
  end
end
