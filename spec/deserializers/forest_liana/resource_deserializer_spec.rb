module ForestLiana
  describe ResourceDeserializer do
    describe 'on a taggable resource (acts_as_taggable_on)' do
      let(:params) do
        ActionController::Parameters.new(
          data: { type: 'Article', attributes: { title: 'Untitled', tags: 'a, b' } }
        )
      end

      it "maps the context attribute to the gem's own _list setter, and drops the original key" do
        attributes = described_class.new(Article, params, false).perform

        expect(attributes['tag_list']).to eq('a, b')
        expect(attributes).not_to have_key('tags')
      end
    end

    describe 'on a non-taggable resource' do
      let(:params) do
        ActionController::Parameters.new(data: { type: 'User', attributes: { name: 'Bilbo' } })
      end

      it 'leaves ordinary attributes untouched' do
        attributes = described_class.new(User, params, false).perform

        expect(attributes['name']).to eq('Bilbo')
      end
    end

    describe 'on a resource with its own taggable?, unrelated to the gem' do
      let(:params) do
        ActionController::Parameters.new(data: { type: 'Tree', attributes: { name: 'oak', tags: 'a, b' } })
      end

      before(:each) { Tree.define_singleton_method(:taggable?) { true } }
      after(:each) { Tree.singleton_class.send(:remove_method, :taggable?) }

      it 'does not raise, since tag_types is acts_as_taggable_on-specific' do
        expect { described_class.new(Tree, params, false).perform }.not_to raise_error
      end
    end
  end
end
