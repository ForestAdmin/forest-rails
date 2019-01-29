require_relative 'json_printer'

module ForestLiana
  class SchemaFileUpdater
    include JsonPrinter

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
      'segments',
      'actions',
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
    KEYS_VALIDATION = [
      'message',
      'type',
      'value',
    ],
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
      'name',
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

    def initialize filename, collections, meta
      @filename = filename
      @meta = meta

      # NOTICE: Remove unecessary keys
      @collections = collections.map do |collection|
        collection['fields'] = collection['fields'].map do |field|
          unless field['validations'].nil?
            field['validations'] = field['validations'].map { |validation| validation.slice(*KEYS_VALIDATION) }
          end
          field.slice(*KEYS_COLLECTION_FIELD)
        end

        collection['actions'] = collection['actions'].map do |action|
          action.slice(*KEYS_ACTION)
          action['fields'] = action['fields'].map { |field| field.slice(*KEYS_ACTION_FIELD) }
          action
        end

        collection['segments'] = collection['segments'].map do |segment|
          segment.slice(*KEYS_SEGMENT)
        end

        collection.slice(*KEYS_COLLECTION)
      end

      # NOTICE: Sort keys
      @collections = @collections.map do |collection|
        collection['fields'].sort do |field1, field2|
          [field1['field'], field1['type']] <=> [field2['field'], field2['type']]
        end

        collection['fields'] = collection['fields'].map do |field|
          unless field['validations'].nil?
            field['validations'] = field['validations'].map do |validation|
              validation.sort_by { |key, value| KEYS_VALIDATION.index key }.to_h
            end
          end
          field.sort_by { |key, value| KEYS_COLLECTION_FIELD.index key }.to_h
        end
        collection['actions'] = collection['actions'].map do |action|
          action.sort_by { |key, value| KEYS_ACTION.index key }.to_h
        end
        collection.sort_by { |key, value| KEYS_COLLECTION.index key }.to_h
      end
      collections.sort { |collection1, collection2| collection1['name'] <=> collection2['name'] }
    end

    def perform
      File.open(@filename, 'w') do |file|
        file.puts pretty_print({
          collections: @collections,
          meta: @meta
        })
      end
    end
  end
end
