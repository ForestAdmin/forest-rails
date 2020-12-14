module ForestLiana
  context 'IsSameDataStructure class' do
    it 'should: be valid with simple data' do
      object = {:a => 'a', :b => 'b'}
      other = {:a => 'a', :b => 'b'}
      result = IsSameDataStructureHelper::Analyser.new(object, other).perform
      expect(result).to be true
    end

    it 'should: be invalid with simple data' do
      object = {:a => 'a', :b => 'b'}
      other = {:a => 'a', :c => 'c'}
      result = IsSameDataStructureHelper::Analyser.new(object, other).perform
      expect(result).to be false
    end

    it 'should: be invalid with not same hash' do
      object = {:a => 'a', :b => 'b'}
      other = {:a => 'a', :b => 'b', :c => 'c'}
      result = IsSameDataStructureHelper::Analyser.new(object, other).perform
      expect(result).to be false
    end

    it 'should: be invalid with nil' do
      object = nil
      other = {:a => 'a', :b => 'b', :c => 'c'}
      result = IsSameDataStructureHelper::Analyser.new(object, other).perform
      expect(result).to be false
    end

    it 'should: be invalid with not hash' do
      object = nil
      other = {:a => 'a', :b => 'b', :c => 'c'}
      result = IsSameDataStructureHelper::Analyser.new(object, other).perform
      expect(result).to be false
    end

    it 'should: be invalid with integer' do
      object = 1
      other = {:a => 'a', :b => 'b', :c => 'c'}
      result = IsSameDataStructureHelper::Analyser.new(object, other).perform
      expect(result).to be false
    end

    it 'should: be invalid with string' do
      object = 'a'
      other = {:a => 'a', :b => 'b', :c => 'c'}
      result = IsSameDataStructureHelper::Analyser.new(object, other).perform
      expect(result).to be false
    end

    it 'should: be valid with depth 1' do
      object = {:a => {:c => 'c'}, :b => {:d => 'd'}}
      other = {:a => {:c => 'c'}, :b => {:d => 'd'}}
      result = IsSameDataStructureHelper::Analyser.new(object, other, 1).perform
      expect(result).to be true
    end

    it 'should: be invalid with depth 1' do
      object = {:a => {:c => 'c'}, :b => {:d => 'd'}}
      other = {:a => {:c => 'c'}, :b => {:e => 'e'}}
      result = IsSameDataStructureHelper::Analyser.new(object, other, 1).perform
      expect(result).to be false
    end

    it 'should: be invalid with depth 1 and nil' do
      object = {:a => {:c => 'c'}, :b => {:d => 'd'}}
      other = {:a => {:c => 'c'}, :b => nil}
      result = IsSameDataStructureHelper::Analyser.new(object, other, 1).perform
      expect(result).to be false
    end

    it 'should: be invalid with depth 1 and integer' do
      object = {:a => {:c => 'c'}, :b => {:d => 'd'}}
      other = {:a => {:c => 'c'}, :b => 1}
      result = IsSameDataStructureHelper::Analyser.new(object, other, 1).perform
      expect(result).to be false
    end

    it 'should: be invalid with depth 1 and string' do
      object = {:a => {:c => 'c'}, :b => {:d => 'd'}}
      other = {:a => {:c => 'c'}, :b => 'b'}
      result = IsSameDataStructureHelper::Analyser.new(object, other, 1).perform
      expect(result).to be false
    end
  end
end
