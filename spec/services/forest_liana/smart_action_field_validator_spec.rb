module ForestLiana
  describe SmartActionFieldValidator do
    describe "self.validate_field" do
      it "should raise an SmartActionInvalidFieldError with nil field" do
        expect { SmartActionFieldValidator.validate_field(nil, "actionName") }.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError, 'Error while parsing action "actionName": The field attribute must be defined')
      end

      it "should raise an SmartActionInvalidFieldError with a field that is not a string" do
        expect { SmartActionFieldValidator.validate_field({
          :field => 5
        }, "actionName") }.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError, 'Error while parsing action "actionName": The field attribute must be a string.')
      end

      it "should raise an SmartActionInvalidFieldError with description that is not a string" do
        expect { SmartActionFieldValidator.validate_field({
          :field => "field",
          :description => 5
        }, "actionName") }.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError, 'Error while parsing action "actionName" on field "field": The description attribute must be a string.')
      end

      it "should raise an SmartActionInvalidFieldError with an enums that is not an array" do
        expect { SmartActionFieldValidator.validate_field({
          :field => "field",
          :enums => "NotAnArray"
        }, "actionName") }.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError, 'Error while parsing action "actionName" on field "field": The enums attribute must be an array.')
      end

      it "should raise an SmartActionInvalidFieldError with a reference that is not a string" do
        expect { SmartActionFieldValidator.validate_field({
          :field => "field",
          :type => "String",
          :reference => 5
        }, "actionName") }.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError, 'Error while parsing action "actionName" on field "field": The reference attribute must be a string.')
      end

      it "should raise an SmartActionInvalidFieldError with an invalid type" do
        expect { SmartActionFieldValidator.validate_field({
          :field => "field",
          :type => "AbsolutelyNotAValidType"
        }, "actionName") }.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldError, 'Error while parsing action "actionName" on field "field": The type attribute must be a valid type. See the documentation for more information. https://docs.forestadmin.com/documentation/reference-guide/fields/create-and-manage-smart-fields#available-field-options.')
      end

      it "should not raise any error when everything is configured correctly" do
        expect { SmartActionFieldValidator.validate_field({
          :field => "field",
          :type => "String",
          :description => "field description"
        }, "actionName") }.not_to raise_error
      end
    end

    describe "self.validate_field_change_hook" do
      it "should raise an SmartActionInvalidFieldHookError with an invalid type" do
        expect { SmartActionFieldValidator.validate_field_change_hook({
          :field => "field",
          :type => "AbsolutelyNotAValidType",
          :hook => "hookThatDoesNotExist"
        }, "actionName", []) }.to raise_error(ForestLiana::Errors::SmartActionInvalidFieldHookError)
      end

      it "should not raise any error when everything is configured correctly" do
        expect { SmartActionFieldValidator.validate_field_change_hook({
          :field => "field",
          :type => "AbsolutelyNotAValidType",
          :hook => "on_field_changed"
        }, "actionName", ["on_field_changed"]) }.not_to raise_error
      end
    end
  end
end
