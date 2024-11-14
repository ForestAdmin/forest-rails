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

      it 'add polymorphic smart field with options' do
        field = collection.fields.select { |field| field[:field] == :addressable_type }.first

        expect(field).not_to be_nil
        expect(field[:is_filterable]).to eq(false)
        expect(field[:is_sortable]).to eq(true)
      end
    end
  end
end
