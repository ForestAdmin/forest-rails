module ForestLiana
  describe SmartFieldDependencies do
    describe '.normalize' do
      it 'wraps a bare String or Symbol into an Array' do
        expect(described_class.normalize('name')).to eq(['name'])
        expect(described_class.normalize(:name)).to eq(['name'])
      end

      it 'strips, dedupes and drops empty entries of an Array' do
        expect(described_class.normalize([' name ', 'name', '', 'age'])).to eq(%w[name age])
      end

      it 'accepts an empty Array' do
        expect(described_class.normalize([])).to eq([])
      end

      it 'answers nil for a shape that is neither a String, a Symbol, nor an Array' do
        expect(described_class.normalize({ nested: 'hash' })).to be_nil
        expect(described_class.normalize(5)).to be_nil
        expect(described_class.normalize(nil)).to be_nil
      end
    end

    describe '#columns and #relation_paths' do
      let(:dependencies) { described_class.new(['name', 'island:name', 'island:location:coordinates']) }

      it 'splits bare column names from relation paths' do
        expect(dependencies.columns).to eq(['name'])
      end

      it 'parses each relation path into its relations and final column' do
        expect(dependencies.relation_paths).to eq([
          described_class::RelationPath.new(['island'], 'name'),
          described_class::RelationPath.new(%w[island location], 'coordinates')
        ])
      end
    end

    describe '.validate!' do
      after do
        Tree._reflections.delete('subject')
        Tree.reflections.delete('subject')
        %w[subject subject= subject_id subject_type].each { |m| Tree.undef_method(m) rescue nil }
      end

      it 'keeps a bare column name that is a real column of the model' do
        field = { field: :cap_name, dependencies: ['name'] }

        expect(FOREST_LOGGER).not_to receive(:warn)
        described_class.validate!(Tree, 'Tree', field)

        expect(field[:dependencies]).to eq(['name'])
      end

      it 'keeps a relation path resolving to a real column on the target model' do
        field = { field: :cap_name, dependencies: ['island:name'] }

        expect(FOREST_LOGGER).not_to receive(:warn)
        described_class.validate!(Tree, 'Tree', field)

        expect(field[:dependencies]).to eq(['island:name'])
      end

      it 'warns and drops the whole declaration for a bare name that is not a real column' do
        field = { field: :cap_name, dependencies: ['not_a_column'] }
        expect(FOREST_LOGGER).to receive(:warn).with(/not_a_column.*cap_name.*Tree/m)

        described_class.validate!(Tree, 'Tree', field)

        expect(field).not_to have_key(:dependencies)
      end

      it 'warns and drops the whole declaration for a relation path naming a fake association' do
        field = { field: :cap_name, dependencies: ['not_a_relation:name'] }
        expect(FOREST_LOGGER).to receive(:warn).with(/not_a_relation:name.*cap_name.*Tree/m)

        described_class.validate!(Tree, 'Tree', field)

        expect(field).not_to have_key(:dependencies)
      end

      it 'warns and drops the whole declaration for a path crossing a polymorphic relation' do
        Tree.class_eval { belongs_to :subject, polymorphic: true, optional: true }
        field = { field: :cap_name, dependencies: ['subject:name'] }
        expect(FOREST_LOGGER).to receive(:warn).with(/subject:name.*cap_name.*Tree/m)

        described_class.validate!(Tree, 'Tree', field)

        expect(field).not_to have_key(:dependencies)
      end

      it "warns and drops the whole declaration rather than crash the boot when a relation's class_name doesn't exist" do
        Tree.class_eval { belongs_to :ghost, class_name: 'TotallyNotARealClass', optional: true }
        field = { field: :cap_name, dependencies: ['ghost:name'] }
        expect(FOREST_LOGGER).to receive(:warn).with(/ghost:name.*cap_name.*Tree/m)

        expect { described_class.validate!(Tree, 'Tree', field) }.not_to raise_error
        expect(field).not_to have_key(:dependencies)
      ensure
        Tree._reflections.delete('ghost')
        Tree._reflections.delete(:ghost)
        Tree.reflections.delete('ghost')
        Tree.reflections.delete(:ghost)
        Tree.clear_reflections_cache
        %w[ghost ghost= ghost_id].each { |m| Tree.undef_method(m) rescue nil }
      end

      it 'does nothing when dependencies is absent' do
        field = { field: :cap_name }
        expect(FOREST_LOGGER).not_to receive(:warn)

        described_class.validate!(Tree, 'Tree', field)

        expect(field).not_to have_key(:dependencies)
      end
    end
  end
end
