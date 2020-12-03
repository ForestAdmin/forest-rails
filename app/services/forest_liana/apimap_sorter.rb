module ForestLiana
  class ApimapSorter
    # TODO: Remove nameOld attribute once the lianas versions older than 2.0.0 are minority.
    KEYS_COLLECTION = [
      'name',
      'name_old',
      'icon',
      'integration',
      'is_read_only',
      'is_searchable',
      'is_virtual',
      'only_for_relationships',
      'pagination_type',
      'fields',
    ]
    KEYS_COLLECTION_FIELD = [
      'field',
      'type',
      'default_value',
      'enums',
      'integration',
      'is_filterable',
      'is_read_only',
      'is_required',
      'is_sortable',
      'is_virtual',
      'reference',
      'inverse_of',
      'relationship',
      'widget',
      'validations',
    ]
    KEYS_ACTION = [
      'name',
      'type',
      'base_url',
      'endpoint',
      'http_method',
      'redirect',
      'download',
      'fields',
    ]
    KEYS_ACTION_FIELD = [
      'field',
      'type',
      'default_value',
      'enums',
      'is_required',
      'reference',
      'description',
      'position',
      'widget',
    ]
    KEYS_SEGMENT = ['name']

    def initialize apimap
      @apimap = apimap.deep_stringify_keys
    end

    def perform
      begin
        @apimap = reorder_keys_basic(@apimap)
        sort_array_of_objects(@apimap['data'])
        @apimap['data'].map! do |collection|
          collection = reorder_keys_child(collection)
          collection['attributes'] = reorder_collection_attributes(collection['attributes'])
          if collection['attributes']['fields']
            collection['attributes']['fields'] = sort_array_of_fields(collection['attributes']['fields'])
            collection['attributes']['fields'].map! { |field| reorder_collection_fields(field) }
          end
          collection
        end

        if @apimap['included']
          sort_array_of_objects(@apimap['included'])

          @apimap['included'].map! do |object|
            object = reorder_keys_child(object)
            if object['type'] === 'actions'
              object['attributes'] = reorder_action_attributes(object['attributes'])
              if object['attributes']['fields']
                object['attributes']['fields'] = sort_array_of_fields(object['attributes']['fields'])
                object['attributes']['fields'].map! { |field| reorder_action_fields(field)  }

              end
            else
              object['attributes'] = reorder_segment_attributes(object['attributes'])
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
      array.sort! do |element1, element2|
        [element1['type'], element1['id']] <=>  [element2['type'], element2['id']]
      end
    end

    def sort_array_of_fields(array)
      array.sort do |field1, field2|
        [field1['field'], field1['type']] <=>  [field2['field'], field2['type']]
      end
    end

    def reorder_keys_basic(object)
      object_reordered = {}
      object.keys.sort.each do |key|
        object_reordered[key] = object[key]
      end
      object_reordered
    end

    def reorder_keys_child(object)
      object_reordered = {}
      object_reordered['type'] = object['type']
      object_reordered['id'] = object['id']
      object_reordered['attributes'] = object['attributes']
      object.keys.sort.each { |key| object_reordered[key] = object[key] }
      object_reordered
    end

    def reorder_collection_attributes(collection_attributes)
      collection_attributes = collection_attributes.slice(*KEYS_COLLECTION)
      collection_attributes.sort_by { |key, value| KEYS_COLLECTION.index key }.to_h
    end

    def reorder_action_attributes(action_attributes)
      action_attributes = action_attributes.slice(*KEYS_ACTION)
      action_attributes.sort_by { |key, value| KEYS_ACTION.index key }.to_h
    end

    def reorder_segment_attributes(segment_attributes)
      segment_attributes = segment_attributes.slice(*KEYS_SEGMENT)
      segment_attributes.sort_by { |key, value| KEYS_SEGMENT.index key }.to_h
    end

    def reorder_collection_fields(field)
      field = field.slice(*KEYS_COLLECTION_FIELD)
      field.sort_by { |key, value| KEYS_COLLECTION_FIELD.index key }.to_h
    end

    def reorder_action_fields(field)
      field = field.slice(*KEYS_ACTION_FIELD)
      field.sort_by { |key, value| KEYS_ACTION_FIELD.index key }.to_h
    end
  end
end
