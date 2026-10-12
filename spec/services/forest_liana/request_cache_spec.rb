module ForestLiana
  describe RequestCache do
    it 'runs the block on every call outside a request' do
      calls = 0
      2.times { described_class.fetch('key') { calls += 1 } }

      expect(calls).to eq(2)
    end

    it 'runs the block once per key within a request' do
      calls = 0
      values = described_class.with { Array.new(2) { described_class.fetch('key') { calls += 1 } } }

      expect(calls).to eq(1)
      expect(values).to eq([1, 1])
    end

    it 'remembers a false value' do
      calls = 0
      described_class.with { 2.times { described_class.fetch('key') { calls += 1; false } } }

      expect(calls).to eq(1)
    end

    it 'answers a written value to the rest of the request' do
      described_class.with do
        described_class.fetch('key') { 'stale' }
        described_class.write('key', 'fresh')

        expect(described_class.fetch('key') { 'unused' }).to eq('fresh')
      end
    end

    it 'runs the block again after a delete' do
      described_class.with do
        described_class.fetch('key') { 'stale' }
        described_class.delete('key')

        expect(described_class.fetch('key') { 'fresh' }).to eq('fresh')
      end
    end

    it 'forgets everything once the request is over' do
      described_class.with { described_class.fetch('key') { 'first' } }

      expect(described_class.with { described_class.fetch('key') { 'second' } }).to eq('second')
      expect(described_class.store).to be_nil
    end
  end
end
