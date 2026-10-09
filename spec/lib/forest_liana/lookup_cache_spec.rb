require 'rails_helper'

describe 'Lookups by name over the schema' do
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
