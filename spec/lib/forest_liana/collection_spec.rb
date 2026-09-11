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
            is_sortable: false
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

    describe 'collection opts' do
      let(:tree) { ForestLiana.apimap.find { |c| c.name == 'Tree' } }

      after { tree.is_read_only = false; tree.is_searchable = true }

      it 'applies read_only and is_searchable to an already-existing (AR-backed) collection' do
        Class.new { include ForestLiana::Collection }.collection(:Tree, read_only: true, is_searchable: false)

        expect(tree.is_read_only).to eq(true)
        expect(tree.is_searchable).to eq(false)
      end

      it 'leaves the collection untouched when no opt is declared' do
        tree.is_read_only = true
        tree.is_searchable = false

        Class.new { include ForestLiana::Collection }.collection(:Tree)

        expect(tree.is_read_only).to eq(true)
        expect(tree.is_searchable).to eq(false)
      end
    end
  end
end
