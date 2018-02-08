module ForestLiana
  class ApimapSorter
    def initialize apimap
      @apimap = apimap.stringify_keys
    end

    def perform
      begin
        @apimap = reorder_keys_basic(@apimap)
        @apimap['data'] = sort_array_of_objects(@apimap['data']);

        @apimap['data'].map! do |collection|
          collection = reorder_keys_child(collection)
          collection['attributes'] = reorder_keys_collection(collection['attributes'])
          if collection['attributes']['fields']
            collection['attributes']['fields'] = sort_array_of_fields(collection['attributes']['fields'])
            collection['attributes']['fields'].map! { |field| reorder_keys_field(field) }
          end
          collection
        end

        if @apimap['included']
          @apimap['included'] = sort_array_of_objects(@apimap['included'])

          @apimap['included'].map! do |object|
            object = reorder_keys_child(object)
            object['attributes'] = reorder_keys_collection(object['attributes'])
            if object['attributes']['fields']
              object['attributes']['fields'] = sort_array_of_fields(object['attributes']['fields'])
              object['attributes']['fields'].map! { |field| reorder_keys_field(field)  }
            end
            object
          end
        end

        @apimap['meta'] = reorder_keys_basic(@apimap['meta'])
        @apimap
      rescue => exception
        FOREST_LOGGER.warn "An Apimap reordering issue occured: #{exception}"
        @apimap
      end
    end

    private

    def sort_array_of_objects(array)
      array.sort do |element1, element2|
        if element1['type'] == element2['type']
          element1['id'] <=> element2['id']
        else
          element1['type'] <=> element2['type']
        end
      end
    end

    def sort_array_of_fields(array)
      return nil unless array

      array.sort do |field1, field2|
        if field1['field'] == field2['field']
          field1['type'] <=> field2['type']
        else
          field1['field'] <=> field2['field']
        end
      end
    end

    def reorder_keys_basic(object)
      object = object.stringify_keys
      object_reordered = {}
      object.keys.sort.each do |key|
        object_reordered[key] = object[key]
      end
      object_reordered
    end

    def reorder_keys_child(object)
      object = object.stringify_keys
      object_reordered = {}
      object_reordered['type'] = object['type']
      object_reordered['id'] = object['id']
      object_reordered['attributes'] = object['attributes']
      object.keys.sort.each { |key| object_reordered[key] = object[key] }
      object_reordered
    end

    def reorder_keys_collection(collection)
      collection = collection.stringify_keys
      collection_reordered_start = {}
      collection_reordered_start['name'] = collection['name']
      collection_reordered_end = {}
      collection_reordered_end['fields'] = collection['fields'] if collection['fields']

      collection.delete('name')
      collection.delete('fields')

      collection_reordered_middle = reorder_keys_basic(collection)

      collection = collection_reordered_start.merge(collection_reordered_middle)
      collection.merge(collection_reordered_end)
    end

    def reorder_keys_field(field)
      field = field.stringify_keys
      field_reordered_start = {}
      field_reordered_start['field'] = field['field']
      field_reordered_start['type'] = field['type']

      field.delete('field')
      field.delete('type')

      field = reorder_keys_basic(field || {})

      field_reordered_start.merge(field)
    end
  end
end
