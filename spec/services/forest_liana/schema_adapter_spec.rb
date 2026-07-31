module ForestLiana
  describe SchemaAdapter do
    describe '#get_type_for' do
      let(:adapter) { described_class.new(Tree) }

      def column_of_type(type)
        double('Column', name: 'some_column', type: type, array: false)
      end

      it 'maps a timestamptz column to the Date type' do
        expect(adapter.send(:get_type_for, column_of_type(:timestamptz))).to eq 'Date'
      end

      it 'maps a timestamp column to the Date type' do
        expect(adapter.send(:get_type_for, column_of_type(:timestamp))).to eq 'Date'
      end

      it 'still maps a datetime column to the Date type' do
        expect(adapter.send(:get_type_for, column_of_type(:datetime))).to eq 'Date'
      end
    end

    describe 'perform' do
      context 'with polymorphic association' do
        it 'should define the association with the referenced models' do
          collection = ForestLiana.apimap.find do |object|
            object.name.to_s == ForestLiana.name_for(Address)
          end
          field = collection.fields.find { |field| field[:field] == 'addressable' }

          expect(field).to eq(
            {
              field: "addressable",
              type: "Number",
              relationship: "BelongsTo",
              reference: "addressable.id",
              inverse_of: "address",
              is_primary_key: false,
              is_filterable: false,
              is_sortable: true,
              is_read_only: false,
              is_required: false,
              is_virtual: false,
              default_value: nil,
              integration: nil,
              relationships: nil,
              widget: nil,
              validations: [],
              polymorphic_referenced_models: ['User'],
              foreign_key_type_field: 'addressable_type'
            }
          )
        end

        it 'should remove the polymorphic attributes(_id and _type)' do
          collection = ForestLiana.apimap.find do |object|
            object.name.to_s == ForestLiana.name_for(Address)
          end
          removed_fields = collection.fields.select do
            |field| field[:field] == 'addressable_id' ||  field[:field] == 'addressable_type'
          end

          expect(removed_fields).to be_empty
        end
      end

      context 'with an "unhandled" column types (binary, postgis geography, ...)' do
        it 'should not define theses column in the schema' do
          collection = ForestLiana.apimap.find do |object|
            object.name.to_s == ForestLiana.name_for(Island)
          end

          expect(collection.fields.map { |field| field[:field] }).to eq(
            ["created_at", "eponymous_tree", "id", "location", "name", "trees", "updated_at"]
          )
        end
      end

      context 'with standard fields' do
        it 'should be sort by alphabetical order' do
          collection = ForestLiana.apimap.find do |object|
            object.name.to_s == ForestLiana.name_for(Tree)
          end

          expect(collection.fields.map { |field| field[:field].to_s}).to eq(
            [
              "age",
              "created_at",
              "cutter",
              "eponymous_island",
              "id",
              "island",
              "location",
              "name",
              "owner",
              "updated_at"
            ]
          )
        end
      end

      context 'with a multiline regex validation' do
        it 'should remove new lines in validation' do

          collection = ForestLiana.apimap.find do |object|
            object.name.to_s == ForestLiana.name_for(Product)
          end

          uri_field = collection.fields.find { |field| field[:field] == 'uri' }
          uri_regex_validation = uri_field[:validations].find { |validation| validation[:type] == "is like"}
          expect(uri_regex_validation[:value].match('\n')).to eq(nil)
        end
      end
    end
  end
end
