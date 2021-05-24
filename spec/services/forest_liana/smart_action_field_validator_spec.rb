module ForestLiana
  describe SmartActionFieldValidator do
    describe 'self.validate_field' do
      it 'should raise an EmptyActionFieldNameError with nil field' do
        expect {SmartActionFieldValidator.validate_field(nil)}.to raise_error(ForestLiana::Errors::EmptyActionFieldNameError)
      end

      it 'should raise an InconsistentActionFieldNameTypeError with a field that is not a string' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 5
        })}.to raise_error(ForestLiana::Errors::InconsistentActionFieldNameTypeError)
      end

      it 'should raise an InconsistentActionFieldDescriptionTypeError with description that is not a string' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 'field',
          :description => 5
        })}.to raise_error(ForestLiana::Errors::InconsistentActionFieldDescriptionTypeError)
      end

      it 'should raise an InconsistentActionFieldEnumsTypeError with an enums that is not an array' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 'field',
          :enums => 'NotAnArray'
        })}.to raise_error(ForestLiana::Errors::InconsistentActionFieldEnumsTypeError)
      end

      it 'should raise an InconsistentActionFieldReferenceTypeError with a reference that is not a string' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 'field',
          :type => 'String',
          :reference => 5
        })}.to raise_error(ForestLiana::Errors::InconsistentActionFieldReferenceTypeError)
      end

      it 'should raise an InvalidActionFieldTypeError with an invalid type' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 'field',
          :type => 'AbsolutelyNotAValidType'
        })}.to raise_error(ForestLiana::Errors::InvalidActionFieldTypeError)
      end
    end
  end
end
