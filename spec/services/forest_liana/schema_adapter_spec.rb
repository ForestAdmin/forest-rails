module ForestLiana
  describe SchemaAdapter do
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
              polymorphic_referenced_models: ['User']
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

        context 'when the polymorphic support was disabled' do
          it 'should not define the association' do
            ENV['ENABLE_SUPPORT_POLYMORPHISM'] = 'false'
            Bootstrapper.new(true)
            collection = ForestLiana.apimap.find do |object|
              object.name.to_s == ForestLiana.name_for(Address)
            end
            association = collection.fields.find { |field| field[:field] == 'addressable' }
            fields = collection.fields.select do |field|
              field[:field] == 'addressable_id' || field[:field] == 'addressable_type'
            end

            expect(association).to be_nil
            expect(fields.size).to eq(2)
          end
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
            ["age", "created_at", "cutter", "eponymous_island", "id", "island", "name", "owner", "updated_at"]
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
