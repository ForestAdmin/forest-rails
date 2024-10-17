module ForestLiana
  describe SmartActionFormParser do
    describe "self.validate_layout_element" do
      it "raise an error with an invalid component" do
        expect { SmartActionFormParser.validate_layout_element({ type: 'Layout', component: 'foo' }) }
          .to raise_error(
            ForestLiana::Errors::HTTP422Error,
            'foo is not a valid component. Valid components are Page or Row or Separator or HtmlBlock'
          )
      end

      it "raise an error with an invalid Page" do
        expect do
          SmartActionFormParser.validate_layout_element(
            { type: 'Layout', component: 'Page', elements: 'foo' }
          )
        end.to raise_error(
            ForestLiana::Errors::HTTP422Error,
            "Page components must contain an array of fields or layout elements in property 'elements'"
          )
      end

      it "raise an error with a Page that contains page" do
        expect do
          SmartActionFormParser.validate_layout_element(
            { type: 'Layout', component: 'Page', elements: [{ type: 'Layout', component: 'Page', elements: [] }] }
          )
        end.to raise_error(ForestLiana::Errors::HTTP422Error, 'Pages cannot contain other pages')
      end

      it "should raise an error with an invalid Row" do
        expect do
          SmartActionFormParser.validate_layout_element(
            { type: 'Layout', component: 'Row', fields: 'foo' }
          )
        end.to raise_error(
          ForestLiana::Errors::HTTP422Error,
          "Row components must contain an array of fields in property 'fields'"
        )
      end

      it "raise an error with a row that contains layout element" do
        expect do
          SmartActionFormParser.validate_layout_element(
            {
              type: 'Layout',
              component: 'Row',
              fields: [ { type: 'Layout', component: 'HtmlBlock', fields: 'Row components can only contain fields' }]
            }
          )
        end.to raise_error(ForestLiana::Errors::HTTP422Error, 'Row components can only contain fields')
      end
    end
  end
end
