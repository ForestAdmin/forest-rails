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
  end
end
