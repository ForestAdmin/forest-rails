module ForestLiana
  describe ApimapSorter do
    describe 'apimap reordering' do
      context 'on a disordered apimap' do
        apimap = {
          'meta': {
            'orm_version': '4.34.9',
            'liana_version': '1.5.24',
            'database_type': 'postgresql',
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
          expect(apimap_sorted['meta'].keys).to eq(
            ['database_type', 'liana', 'liana_version', 'orm_version'])
        end
      end
    end
  end
end
