module ForestLiana
  describe ApimapSorter do
    describe 'apimap reordering' do
      context 'on a disordered apimap' do
        apimap = {
          'meta': {
            stack: {
              'orm_version': '4.34.9',
              'database_type': 'postgresql',
            },
            'liana_version': '1.5.24',
            liana: 'forest-rails',
          },
          'data': [{
            id: 'users',
            type: 'collections',
            attributes: {
              fields: [
                { field: 'id', type: 'Number' },
                { field: 'name', type: 'String' },
                { field: 'firstName', type: 'String' },
                { field: 'lastName', type: 'String' },
                { field: 'email', type: 'String' },
                { field: 'url', type: 'String' },
                { field: 'createdAt', type: 'Date' },
                { field: 'updatedAt', type: 'Date' },
              ],
              name: 'users',
            }
          }, {
            id: 'guests',
            type: 'collections',
            attributes: {
              fields: [
                { field: 'id', type: 'Number' },
                { field: 'email', type: 'String' },
                { field: 'createdAt', type: 'Date' },
                { field: 'updatedAt', type: 'Date' },
              ],
              name: 'guests',
            }
          }, {
            type: 'collections',
            id: 'animals',
            attributes: {
              fields: [
                { is_sortable: false, field: 'id', is_filterable: false,  type: 'Number' },
                { type: 'Date', field: 'createdAt' },
                { field: 'updatedAt', type: 'Date' },
              ],
              name: 'animals',
              integration: 'close.io',
              is_virtual: true,
            }
          }],
          'included': [{
            id: 'users.Women',
            type: 'segments',
            attributes: {
              name: 'Women'
            }
          }, {
            id: 'users.import',
            type: 'actions',
            links: {
              self: '/actions'
            },
            attributes: {
              name: 'import',
              fields: [{
                is_required: true,
                type: 'Boolean',
                field: 'Save',
                description: 'save the import file if true.',
                default_value: 'true'
              }, {
                type: 'File',
                field: 'File'
              }],
              http_method: nil,
              hooks: nil,
            }
          }, {
            attributes: {
              name: 'Men'
            },
            id: 'users.Men',
            type: 'segments'
          }, {
            id: 'animals.ban',
            type: 'actions',
            links: {
              self: '/actions'
            },
            attributes: {
              name: 'import',
              global: true,
              download: nil,
              endpoint: nil,
              redirect: nil,
              'http_method': nil,
              hooks: nil,
            }
          }]
        }

        apimap = ActiveSupport::JSON.encode(apimap)
        apimap = ActiveSupport::JSON.decode(apimap)
        apimap_sorted = ApimapSorter.new(apimap).perform

        it 'should sort the apimap sections' do
          expect(apimap_sorted.keys).to eq(['data', 'included', 'meta'])
        end

        it 'should sort the data collections' do
          expect(apimap_sorted['data'].map { |collection| collection['id'] }).to eq(
            ['animals', 'guests', 'users'])
        end

        it 'should sort the data collection values' do
          expect(apimap_sorted['data'][0].keys).to eq(['type', 'id', 'attributes'])
          expect(apimap_sorted['data'][1].keys).to eq(['type', 'id', 'attributes'])
          expect(apimap_sorted['data'][2].keys).to eq(['type', 'id', 'attributes'])
        end

        it 'should sort the data collections attributes values' do
          expect(apimap_sorted['data'][0]['attributes'].keys).to eq(['name', 'integration', 'is_virtual', 'fields'])
          expect(apimap_sorted['data'][1]['attributes'].keys).to eq(['name', 'fields'])
          expect(apimap_sorted['data'][2]['attributes'].keys).to eq(['name', 'fields'])
        end

        it 'should sort the data collections attributes fields by name' do
          expect(apimap_sorted['data'][0]['attributes']['fields'].map { |field| field['field'] }).to eq(['createdAt', 'id', 'updatedAt'])
          expect(apimap_sorted['data'][1]['attributes']['fields'].map { |field| field['field'] }).to eq(['createdAt', 'email', 'id', 'updatedAt'])
          expect(apimap_sorted['data'][2]['attributes']['fields'].map { |field| field['field'] }).to eq(['createdAt', 'email', 'firstName', 'id', 'lastName', 'name', 'updatedAt', 'url'])
        end

        it 'should sort the data collections attributes fields values' do
          expect(apimap_sorted['data'][0]['attributes']['fields'][1].keys).to eq(['field', 'type', 'is_filterable', 'is_sortable'])
        end

        it 'should sort the included actions and segments objects' do
          expect(apimap_sorted['included'].map { |object| object['id'] }).to eq(
            ['animals.ban', 'users.import', 'users.Men', 'users.Women'])
        end

        it 'should sort the included actions and segments objects values' do
          expect(apimap_sorted['included'][0].keys).to eq(['type', 'id', 'attributes', 'links'])
          expect(apimap_sorted['included'][1].keys).to eq(['type', 'id', 'attributes', 'links'])
          expect(apimap_sorted['included'][2].keys).to eq(['type', 'id', 'attributes'])
          expect(apimap_sorted['included'][3].keys).to eq(['type', 'id', 'attributes'])
        end

        it 'should sort the included actions and segments objects attributes values' do
          expect(apimap_sorted['included'][0]['attributes'].keys).to eq(['name', 'endpoint', 'http_method', 'redirect', 'download', 'hooks'])
          expect(apimap_sorted['included'][1]['attributes'].keys).to eq(['name', 'http_method', 'fields', 'hooks'])
          expect(apimap_sorted['included'][2]['attributes'].keys).to eq(['name'])
          expect(apimap_sorted['included'][3]['attributes'].keys).to eq(['name'])
        end

        it 'should sort the included action attributes fields by name' do
          expect(apimap_sorted['included'][1]['attributes']['fields'].map { |field| field['field'] }).to eq(['File', 'Save'])
        end

        it 'should sort the included action fields values' do
          expect(apimap_sorted['included'][1]['attributes']['fields'][1].keys).to eq(['field', 'type', 'default_value', 'is_required', 'description'])
        end

        it 'should sort the meta values' do
          expect(apimap_sorted['meta'].keys).to eq(['liana', 'liana_version', 'stack'])
          expect(apimap_sorted['meta']['stack'].keys).to eq(['database_type', 'orm_version'])
        end
      end

      context 'on an apimap with fields sharing a name but not a comparable type' do
        # NOTICE: a field 'type' is a String ('String'), an Array (['String'] for an array
        # column) or a Hash (a nested type). The sort used to compare those values
        # directly, so `['String'] <=> 'String'` returned nil and `sort` raised
        # `ArgumentError: comparison of Hash with Hash failed`. The rescue in `perform`
        # swallowed it and returned a half-processed apimap: collections that were never
        # reached kept attributes outside KEYS_COLLECTION (such as 'search_fields'), and
        # the Forest API rejects those with `HTTP 400 ValidationFailedError`.
        apimap = {
          'meta': {
            liana: 'forest-rails',
            'liana_version': '1.5.24',
          },
          'data': [{
            id: 'posts',
            type: 'collections',
            attributes: {
              name: 'posts',
              fields: [
                { field: 'tags', type: ['String'] },
                { field: 'tags', type: 'String' },
                { field: 'meta', type: { fields: [{ field: 'locale', type: 'String' }] } },
                { field: 'meta', type: 'String' },
                { field: 'id', type: 'Number' },
              ],
            }
          }, {
            id: 'zebras',
            type: 'collections',
            attributes: {
              'search_fields': ['name'],
              fields: [
                { field: 'id', type: 'Number' },
              ],
              name: 'zebras',
            }
          }]
        }

        apimap = ActiveSupport::JSON.encode(apimap)
        apimap = ActiveSupport::JSON.decode(apimap)
        apimap_sorted = ApimapSorter.new(apimap).perform

        it 'should sort the fields of the offending collection' do
          expect(apimap_sorted['data'][0]['attributes']['fields'].map { |field| field['field'] })
            .to eq(['id', 'meta', 'meta', 'tags', 'tags'])
        end

        it 'should keep a deterministic order between the non-comparable types' do
          tag_types = apimap_sorted['data'][0]['attributes']['fields']
            .select { |field| field['field'] == 'tags' }
            .map { |field| field['type'] }
          expect(tag_types).to eq(['String', ['String']])
        end

        it 'should keep processing the collections after the offending one' do
          expect(apimap_sorted['data'][1]['attributes'].keys).to eq(['name', 'fields'])
        end

        it 'should not leak collection attributes that are not part of the schema' do
          expect(apimap_sorted['data'][1]['attributes']).not_to have_key('search_fields')
        end
      end
    end

    describe 'a smart field dependencies key' do
      # dependencies: is a server-side hint (what to select/preload), not part of the schema the
      # front end consumes — KEYS_COLLECTION_FIELD's slice is what keeps it out of the payload.
      let(:apimap) do
        {
          meta: { liana: 'forest-rails', liana_version: '1.0.0', stack: { orm_version: '1', database_type: 'sqlite' } },
          data: [{
            id: 'trees', type: 'collections',
            attributes: { name: 'trees', fields: [{ field: 'cap_name', type: 'String', dependencies: ['name'] }] }
          }]
        }
      end

      it 'is stripped from the emitted field payload' do
        sorted = described_class.new(apimap).perform

        expect(sorted['data'][0]['attributes']['fields'][0]).not_to have_key('dependencies')
      end
    end
  end
end
