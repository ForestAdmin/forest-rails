module ForestLiana
  describe SchemaFileUpdater do
    describe "initialize" do
      describe "without any collections nor meta" do
        it "should set collections as an empty array and meta as an empty object" do
          schema_file_updater = ForestLiana::SchemaFileUpdater.new("test.txt", [], {})
          expect(schema_file_updater.instance_variable_get(:@collections)).to eq([])
          expect(schema_file_updater.instance_variable_get(:@meta)).to eq({})
        end
      end

      describe "with a given collection" do
        describe "when the collection has a polymorphic relation" do
          it "should save the relation" do
            collections = [
              {
                "name" => "Address",
                "fields" => [
                  {
                    "field" => "addressable",
                    "type" => "Number",
                    "relationship" => "BelongsTo",
                    "reference" => "addressable.id",
                    "inverse_of" => "address",
                    "is_filterable" => false,
                    "is_sortable" => true,
                    "is_read_only" => false,
                    "is_required" => false,
                    "is_virtual" => false,
                    "default_value" => nil,
                    "integration" => nil,
                    "relationships" => nil,
                    "widget" => nil,
                    "validations" => [],
                    "polymorphic_referenced_models" => ["User"]
                  },
                ],
                "actions" => [],
                "segments" => []
              }
            ]
            schema_file_updater = ForestLiana::SchemaFileUpdater.new("test.txt", collections, {})
            expect(schema_file_updater.instance_variable_get(:@collections))
              .to eq(collections)
          end
        end

        describe "when the collection has a smart action action" do
          it "should save the smart action" do
            collections = [{
              "fields" => [],
              "actions" => [{
                "fields" => [],
                "name" => "test",
                "hooks" => {
                  "change" => []
                }
              }],
              "segments" => []
            }]
            schema_file_updater = ForestLiana::SchemaFileUpdater.new("test.txt", collections, {})
            expect(schema_file_updater.instance_variable_get(:@collections))
              .to eq(collections)
          end

          describe "when a smart action field is malformed" do
            it "should display a warning message" do
              collections = [{
                "fields" => [],
                "actions" => [{
                  "fields" => [{}],
                  "name" => "test",
                  "hooks" => {
                    "change" => []
                  }
                }],
                "segments" => []
              }]
              allow(FOREST_LOGGER).to receive(:warn)
              schema_file_updater = ForestLiana::SchemaFileUpdater.new("test.txt", collections, {})
              expect(FOREST_LOGGER).to have_received(:warn).with('Error while parsing action "test": The field attribute must be defined')
            end
          end

          describe "when a smart action change field hook does not exist" do
            it "should display an error message" do
              collections = [{
                "fields" => [],
                "actions" => [{
                  "fields" => [{
                    "field" => "testField",
                    "hook" => "undefinedHook",
                    "type" => "String",
                  }],
                  "name" => "test",
                  "hooks" => {
                    "change" => []
                  }
                }],
                "segments" => []
              }]

              allow(FOREST_LOGGER).to receive(:error)
              schema_file_updater = ForestLiana::SchemaFileUpdater.new("test.txt", collections, {})
              expect(FOREST_LOGGER).to have_received(:error).with('The hook "undefinedHook" of "testField" field on the smart action "test" is not defined.')
            end
          end
        end
      end
    end

    describe "perform" do
      it "should call file puts with pretty printed data" do
        file = instance_double(File, read: "stubbed read")

        allow(File).to receive(:open).with("test.txt", "w") { |&block| block.call(file) }

        schema_file_updater = ForestLiana::SchemaFileUpdater.new("test.txt", [], {})
        expected_result = schema_file_updater.pretty_print({
          "collections" => [],
          "meta" => {}
        })

        expect(file).to receive(:puts).with(expected_result)
        schema_file_updater.perform
      end
    end
  end
end
