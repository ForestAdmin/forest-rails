module ForestLiana
  describe SearchQueryBuilder do
    let(:user) { { 'id' => '1', 'rendering_id' => 1 } }
    let(:collection) { ForestLiana::Model::Collection.new(name: 'Tree', fields: []) }
    let(:search_uuid) { '75fbcb43-f6f8-4cd1-861f-09a61fd1ddad' }
    let(:params) { { search: search_uuid, searchExtended: '0' } }
    let(:builder) { described_class.new(params, [], collection, user) }

    before do
      allow(ForestLiana::ScopeManager)
        .to receive(:append_scope_for_user)
        .and_return(nil)
      allow(ForestLiana)
        .to receive(:schema_for_resource)
        .and_return(ForestLiana::Model::Collection.new(name: 'Tree', fields: []))
    end

    describe '#perform' do
      context 'when a column is an array uuid type' do
        let(:array_uuid_column) do
          double('Column', name: 'attachment_ids', type: :uuid, array: true).tap do |col|
            allow(col).to receive(:respond_to?).with(:array).and_return(true)
          end
        end

        let(:normal_uuid_column) do
          double('Column', name: 'external_id', type: :uuid, array: false).tap do |col|
            allow(col).to receive(:respond_to?).with(:array).and_return(true)
          end
        end

        before do
          allow(Tree).to receive(:columns).and_return([array_uuid_column, normal_uuid_column])
        end

        it 'searches the array column using ANY() syntax' do
          result = builder.perform(Tree.all)
          expect(result.to_sql).to match(/= ANY.*attachment_ids/i)
        end

        it 'searches the non-array uuid column using equality syntax' do
          result = builder.perform(Tree.all)
          expect(result.to_sql).to match(/"external_id"\s+=\s+'#{search_uuid}'/i)
        end
      end
    end
  end
end
