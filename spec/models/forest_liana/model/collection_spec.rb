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
        let(:mixed_collection) do
          described_class.new(name: 'Tree', fields: [
            computed_field(:cap_name, dependencies_declared: true, deps: ['name']),
            computed_field(:other, dependencies_declared: false)
          ])
        end

        let(:collection_with_relation) do
          described_class.new(name: 'Tree', fields: [
            computed_field(:cap_name, dependencies_declared: true, deps: ['name']),
            smart_relation(:owner)
          ])
        end

        # Per request, not per collection: should_include_attr? never evaluates a field the
        # request didn't ask for, so an undeclared field elsewhere in the collection can't read
        # anything this request would need to worry about.
        it "is true when the request never names the collection's one undeclared computed field" do
          expect(mixed_collection.smart_fields_projectable?(%w[id cap_name])).to be true
        end

        it 'is false as soon as a requested computed smart field does not declare' do
          expect(mixed_collection.smart_fields_projectable?(%w[id other])).to be false
        end

        it 'is false when the request names a smart relation, which has no way to declare' do
          expect(collection_with_relation.smart_fields_projectable?(%w[id cap_name owner])).to be false
        end

        it 'is true when the request never names the smart relation' do
          expect(collection_with_relation.smart_fields_projectable?(%w[id cap_name])).to be true
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
