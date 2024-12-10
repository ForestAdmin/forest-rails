class Forest::Address
    include ForestLiana::Collection

    collection :Address

    field :addressable_type, type: 'String', polymorphic_key: true, is_filterable: false do
      object.addressable_type
    end

    field :addressable_id, type: 'String', polymorphic_key: true do
      object.addressable_type
    end

    field :address_type, type: 'String' do
      'delivery'
    end
end
