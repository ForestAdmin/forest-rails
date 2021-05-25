module ForestLiana
  describe SmartActionFieldValidator do
    describe 'self.validate_field' do
      it 'should raise an SmartActionInvalidFieldError with nil field' do
        expect {SmartActionFieldValidator.validate_field(nil, 'actionName')}.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError)
      end

      it 'should raise an SmartActionInvalidFieldError with a field that is not a string' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 5
        }, 'actionName')}.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError)
      end

      it 'should raise an SmartActionInvalidFieldError with description that is not a string' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 'field',
          :description => 5
        }, 'actionName')}.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError)
      end

      it 'should raise an SmartActionInvalidFieldError with an enums that is not an array' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 'field',
          :enums => 'NotAnArray'
        }, 'actionName')}.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError)
      end

      it 'should raise an SmartActionInvalidFieldError with a reference that is not a string' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 'field',
          :type => 'String',
          :reference => 5
        }, 'actionName')}.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError)
      end

      it 'should raise an SmartActionInvalidFieldError with an invalid type' do
        expect {SmartActionFieldValidator.validate_field({
          :field => 'field',
          :type => 'AbsolutelyNotAValidType'
        }, 'actionName')}.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError)
      end
    end
  end
end
