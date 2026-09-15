module ForestLiana
  describe MissingAttributeValve do
    let(:dummy_class) { Class.new { include ForestLiana::MissingAttributeValve } }
    let(:dummy) { dummy_class.new }

    describe '#missing_column_from (private)' do
      it "extracts the column from Rails <= 7.0's message shape" do
        exception = ActiveModel::MissingAttributeError.new('missing attribute: name')

        expect(dummy.send(:missing_column_from, exception)).to eq('name')
      end

      it "extracts the column from Rails >= 7.1's message shape" do
        exception = ActiveModel::MissingAttributeError.new("missing attribute 'name' for Owner")

        expect(dummy.send(:missing_column_from, exception)).to eq('name')
      end

      it 'answers nil for a message shape it does not recognize' do
        exception = ActiveModel::MissingAttributeError.new('something else entirely')

        expect(dummy.send(:missing_column_from, exception)).to be_nil
      end
    end
  end
end
