require 'rails_helper'

describe 'Lookups by name over the schema' do
  describe 'ForestLiana::LookupCache.fetch' do
    it 'answers a remembered lookup without allocating' do
      ForestLiana::LookupCache.fetch(:spec, :key) { :value }

      allocated = GC.stat(:total_allocated_objects)
      1_000.times { ForestLiana::LookupCache.fetch(:spec, :key) { :value } }

      expect(GC.stat(:total_allocated_objects) - allocated).to be < 100
    end
  end

  describe 'ForestLiana.name_for' do
    after { ForestLiana.names_overriden.delete(Tree) }

    it 'answers an override registered after a first lookup' do
      expect(ForestLiana.name_for(Tree)).to eq 'Tree'

      ForestLiana.names_overriden[Tree] = 'Orchard'

      expect(ForestLiana.name_for(Tree)).to eq 'Orchard'
    end
  end

  describe 'ForestLiana::SchemaUtils.find_model_from_collection_name' do
    let(:ghost) { Class.new(ActiveRecord::Base) { self.table_name = 'trees' } }

    after do
      ForestLiana.models.delete(ghost)
      ForestLiana.names_overriden.delete(ghost)
    end

    it 'scans the models once for repeated lookups of a name' do
      expect(ForestLiana::SchemaUtils).to receive(:scan_models_for_collection_name).with('Tree').once.and_call_original

      3.times { expect(ForestLiana::SchemaUtils.find_model_from_collection_name('Tree')).to eq Tree }
    end

    it 'does not remember an unknown name, which any caller can send before authenticating' do
      expect(ForestLiana::SchemaUtils).to receive(:scan_models_for_collection_name).with('Ghost').twice.and_call_original

      2.times { expect(ForestLiana::SchemaUtils.find_model_from_collection_name('Ghost')).to be_nil }
    end

    it 'still warns on each lookup of an unknown name' do
      expect(FOREST_LOGGER).to receive(:warn).with('No model found for collection Ghost').twice

      2.times { expect(ForestLiana::SchemaUtils.find_model_from_collection_name('Ghost', true)).to be_nil }
    end

    it 'finds a model added after a first lookup missed it' do
      expect(ForestLiana::SchemaUtils.find_model_from_collection_name('Ghost')).to be_nil

      ForestLiana.names_overriden[ghost] = 'Ghost'
      ForestLiana.models << ghost

      expect(ForestLiana::SchemaUtils.find_model_from_collection_name('Ghost')).to eq ghost
    end
  end

  describe 'ForestLiana::SchemaUtils.polymorphic_models' do
    let(:addressable) { Address.reflect_on_association(:addressable) }

    it 'scans the models once for repeated lookups of a relation' do
      expect(ForestLiana::SchemaUtils).to receive(:scan_polymorphic_models).with(:addressable).once.and_call_original

      3.times { expect(ForestLiana::SchemaUtils.polymorphic_models(addressable)).to eq [User] }
    end

    it 'returns a frozen list' do
      expect(ForestLiana::SchemaUtils.polymorphic_models(addressable)).to be_frozen
    end

    it 'remembers a relation no model targets' do
      orphan = double(name: :orphan)
      expect(ForestLiana::SchemaUtils).to receive(:scan_polymorphic_models).with(:orphan).once.and_call_original

      2.times { expect(ForestLiana::SchemaUtils.polymorphic_models(orphan)).to eq [] }
    end

    it 'finds a target added to the models after a first lookup' do
      target = Class.new(ActiveRecord::Base) do
        self.table_name = 'trees'
        has_many :addresses, as: :addressable
      end
      expect(ForestLiana::SchemaUtils.polymorphic_models(addressable)).to eq [User]

      ForestLiana.models << target

      expect(ForestLiana::SchemaUtils.polymorphic_models(addressable)).to contain_exactly(User, target)
    ensure
      ForestLiana.models.delete(target)
    end
  end

  describe 'ForestLiana::SchemaUtils.associations' do
    it 'reflects on a model once for repeated lookups, a relation included' do
      expect(ForestLiana::SchemaUtils).to receive(:scan_associations).with(Tree).once.and_call_original

      expected = Tree.reflect_on_all_associations.map(&:name)
      expect(ForestLiana::SchemaUtils.associations(Tree).map(&:name)).to match_array(expected)
      expect(ForestLiana::SchemaUtils.associations(Tree.where(name: 'oak')).map(&:name)).to match_array(expected)
    end

    it 'keeps only the to-many associations for many_associations' do
      expect(ForestLiana::SchemaUtils.many_associations(Tree).map(&:name)).to eq([:owner_named_trees])
    end
  end

  describe 'ForestLiana::QueryHelper.get_one_associations' do
    it 'computes the to-one associations of a model once for repeated lookups' do
      expect(ForestLiana::QueryHelper).to receive(:scan_one_associations).with(Address).once.and_call_original

      3.times { expect(ForestLiana::QueryHelper.get_one_associations(Address).map(&:name)).to eq [:addressable] }
    end

    it 'returns a frozen list' do
      expect(ForestLiana::QueryHelper.get_one_associations(Address)).to be_frozen
    end

    it 'drops a target excluded after a first lookup' do
      previous = ForestLiana.excluded_models
      expect(ForestLiana::QueryHelper.get_one_associations(Address).map(&:name)).to eq [:addressable]

      ForestLiana.excluded_models = previous + ['User']

      expect(ForestLiana::QueryHelper.get_one_associations(Address)).to eq []
    ensure
      ForestLiana.excluded_models = previous
    end

    it 'drops a target excluded by a replacement list of the same size' do
      previous = ForestLiana.excluded_models
      ForestLiana.excluded_models = previous + ['Tree']
      expect(ForestLiana::QueryHelper.get_one_associations(Address).map(&:name)).to eq [:addressable]

      ForestLiana.excluded_models = previous + ['User']

      expect(ForestLiana::QueryHelper.get_one_associations(Address)).to eq []
    ensure
      ForestLiana.excluded_models = previous
    end

    it 'drops a target left out of the included models after a first lookup' do
      previous = ForestLiana.included_models
      expect(ForestLiana::QueryHelper.get_one_associations(Address).map(&:name)).to eq [:addressable]

      ForestLiana.included_models = ['Address']

      expect(ForestLiana::QueryHelper.get_one_associations(Address)).to eq []
    ensure
      ForestLiana.included_models = previous
    end

    it 'answers a relation from the lookup of its model' do
      expect(ForestLiana::QueryHelper).to receive(:scan_one_associations).with(Address).once.and_call_original

      expect(ForestLiana::QueryHelper.get_one_associations(Address).map(&:name)).to eq [:addressable]
      expect(ForestLiana::QueryHelper.get_one_associations(Address.where(city: 'Papeete')).map(&:name)).to eq [:addressable]
    end
  end

  describe 'ForestLiana.schema_for_resource' do
    it 'resolves the collection of a resource once for repeated lookups' do
      expect(ForestLiana.schema_for_resource(Tree).name).to eq 'Tree'
      expect(ForestLiana::SchemaUtils).not_to receive(:find_model_from_collection_name)

      expect(ForestLiana.schema_for_resource(Tree).name).to eq 'Tree'
    end

    it 'answers from the apimap in place when it is replaced' do
      expect(ForestLiana.schema_for_resource(Tree).name).to eq 'Tree'
      replacement = ForestLiana::Model::Collection.new(name: 'Tree', fields: [])
      allow(ForestLiana).to receive(:apimap).and_return([replacement])

      expect(ForestLiana.schema_for_resource(Tree)).to equal replacement
    end
  end
end
