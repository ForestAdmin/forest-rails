require_relative 'json_printer'

module ForestLiana
  class SchemaFileUpdater
    include JsonPrinter

    KEYS_COLLECTION = [
      'name',
      'nameOld',
      'displayName',
      'icon',
      'integration',
      'isReadOnly',
      'isSearchable',
      'isVirtual',
      'onlyForRelationships',
      'paginationType',
      'fields',
      'segments',
      'actions'
    ]
    KEYS_COLLECTION_FIELD = [
      'field',
      'type',
      'column',
      'defaultValue',
      'enums',
      'integration',
      'isFilterable',
      'isReadOnly',
      'isRequired',
      'isSortable',
      'isVirtual',
      'reference',
      'inverseOf',
      'relationship',
      'widget',
      'validations'
    ]
    KEYS_FIELD_VALIDATION = [
      'message',
      'type',
      'value',
    ],
    KEYS_ACTION = [
      'name',
      'type',
      'baseUrl',
      'endpoint',
      'httpMethod',
      'download',
      'redirect',
      'global',
      'fields'
    ]
    KEYS_SEGMENT = ['name']

    def initialize filename, collections, meta
      @filename = filename
      @meta = meta

      # NOTICE: Remove unecessary keys
      @collections = collections.map do |collection|
        collection['fields'] = collection['fields'].map do |field|
          unless field['validations'].nil?
            field['validations'] = field['validations'].map { |validation| validation.slice(*KEYS_FIELD_VALIDATION) }
          end
          field.slice(*KEYS_COLLECTION_FIELD)
        end

        collection['actions'] = collection['actions'].map do |action|
          action.slice(*KEYS_ACTION)
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
              validation.sort_by { |key, value| KEYS_FIELD_VALIDATION.index key }.to_h
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
