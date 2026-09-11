module ForestLiana
  describe Collection do
    before do
      allow(ForestLiana).to receive(:env_secret).and_return(nil)
    end

    let(:collection) { ForestLiana.apimap.select { |collection| collection.name == 'Address' }.first }

    describe 'field' do
      it 'add simple smart field' do
        field = collection.fields.select { |field| field[:field] == :address_type }.first

        expect(field).not_to be_nil
        expect(field).to eq(
          {
            type: "String",
            is_read_only: true,
            is_required: false,
            default_value: nil,
            integration: nil,
            reference: nil,
            inverse_of: nil,
            relationships: nil,
            widget: nil,
            validations: [],
            is_virtual: true,
            field: :address_type,
            is_primary_key: false,
            is_filterable: false,
            is_sortable: false,
            dependencies: []
          }
        )
      end

      it 'add polymorphic smart field with default values' do
        field = collection.fields.select { |field| field[:field] == :addressable_id }.first

        expect(field).not_to be_nil
        expect(field[:is_filterable]).to eq(true)
        expect(field[:is_sortable]).to eq(true)
      end

      it 'add polymorphic smart field with is_filterable option set to false' do
        field = collection.fields.select { |field| field[:field] == :addressable_type }.first

        expect(field).not_to be_nil
        expect(field[:is_filterable]).to eq(false)
        expect(field[:is_sortable]).to eq(true)
      end
    end

    describe 'normalize_dependencies!' do
      let(:dummy_class) { Class.new { extend ForestLiana::Collection::ClassMethods } }

      it 'leaves opts untouched when dependencies is absent' do
        opts = { type: 'String' }

        dummy_class.normalize_dependencies!(opts, :some_field)

        expect(opts).not_to have_key(:dependencies)
      end

      it 'wraps a bare String or Symbol into an Array' do
        opts = { dependencies: 'name' }
        dummy_class.normalize_dependencies!(opts, :some_field)
        expect(opts[:dependencies]).to eq(['name'])

        opts = { dependencies: :name }
        dummy_class.normalize_dependencies!(opts, :some_field)
        expect(opts[:dependencies]).to eq(['name'])
      end

      it 'strips, dedupes and drops empty entries' do
        opts = { dependencies: [' name ', 'name', ''] }

        dummy_class.normalize_dependencies!(opts, :some_field)

        expect(opts[:dependencies]).to eq(['name'])
      end

      it 'accepts an empty Array as a genuine declaration (a constant getter reads no column)' do
        opts = { dependencies: [] }

        dummy_class.normalize_dependencies!(opts, :some_field)

        expect(opts[:dependencies]).to eq([])
      end

      it 'treats an explicit nil the same as an absent key' do
        opts = { dependencies: nil }

        dummy_class.normalize_dependencies!(opts, :some_field)

        expect(opts).not_to have_key(:dependencies)
      end

      it 'warns and removes the key for an invalid shape, rather than crashing' do
        opts = { dependencies: { nested: 'hash' } }
        expect(FOREST_LOGGER).to receive(:warn).with(/some_field/)

        dummy_class.normalize_dependencies!(opts, :some_field)

        expect(opts).not_to have_key(:dependencies)
      end
    end
  end
end
