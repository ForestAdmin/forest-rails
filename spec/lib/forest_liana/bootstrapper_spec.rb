module ForestLiana
  describe Bootstrapper do
    describe 'setup_forest_liana_meta' do
      it "should put statistic data related to user stack on a dedicated object" do
        expect(ForestLiana.meta[:stack])
          .to include(:orm_version)
        expect(ForestLiana.meta[:stack])
          .to include(:database_type)
      end
    end

    describe 'generate_action_hooks' do
      schema = '{
        "collections": [
          {
            "name": "Island",
            "name_old": "Island",
            "icon": null,
            "is_read_only": false,
            "is_searchable": true,
            "is_virtual": false,
            "only_for_relationships": false,
            "pagination_type": "page",
            "fields": [
              {
                "field": "id",
                "type": "Number",
                "default_value": null,
                "enums": null,
                "integration": null,
                "is_filterable": true,
                "is_read_only": false,
                "is_required": false,
                "is_sortable": true,
                "is_virtual": false,
                "reference": null,
                "inverse_of": null,
                "widget": null,
                "validations": []
              },
              {
                "field": "first_name",
                "type": "String",
                "default_value": null,
                "enums": null,
                "integration": null,
                "is_filterable": true,
                "is_read_only": false,
                "is_required": false,
                "is_sortable": true,
                "is_virtual": false,
                "reference": null,
                "inverse_of": null,
                "widget": null,
                "validations": []
              },
              {
                "field": "last_name",
                "type": "String",
                "default_value": null,
                "enums": null,
                "integration": null,
                "is_filterable": true,
                "is_read_only": false,
                "is_required": false,
                "is_sortable": true,
                "is_virtual": false,
                "reference": null,
                "inverse_of": null,
                "widget": null,
                "validations": []
              }
            ],
            "segments": [],
            "actions": [
              {
                "name": "foo",
                "type": "bulk",
                "base_url": null,
                "endpoint": "forest/actions/mark-as-live",
                "http_method": "POST",
                "redirect": null,
                "download": false,
                "fields": [],
                "hooks": {
                  "load": false,
                  "change": []
                }
              }
            ]
          }
        ],
        "meta": {
          "liana": "forest-rails",
          "liana_version": "7.6.0",
          "stack": {
            "database_type": "postgresql",
            "orm_version": "7.0.2.4"
          }
        }
      }'


      it "Should return actions hooks empty for the island collection" do
        allow(ForestLiana).to receive(:env_secret).and_return(nil)
        bootstrapper = Bootstrapper.new
        content = JSON.parse(schema)
        bootstrapper.instance_variable_set(:@collections_sent, content['collections'])
        bootstrapper.instance_variable_set(:@meta_sent, content['meta'])
        bootstrapper.send(:generate_action_hooks)

        expect(bootstrapper.instance_variable_get("@collections_sent").first['actions'].first['hooks']).to eq({"load"=>false, "change"=>[]})
      end
    end
  end
end
