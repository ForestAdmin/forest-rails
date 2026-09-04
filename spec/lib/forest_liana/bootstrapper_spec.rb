module ForestLiana
  describe Bootstrapper do
    before do
      allow(ForestLiana).to receive(:env_secret).and_return(nil)
    end

    describe 'setup_forest_liana_meta' do
      it "should put statistic data related to user stack on a dedicated object" do
        expect(ForestLiana.meta[:stack])
          .to include(:orm_version)
        expect(ForestLiana.meta[:stack])
          .to include(:database_type)
      end
    end

    describe 'models' do
      let(:application_models) do
        ForestLiana.models.reject do |model|
          rails_models.any? { |rails_model| model <= rails_model }
        end
      end
      # Rails 7.1 stopped making these ActiveRecord::Base descendants (they became per-connection,
      # dynamically generated), so ForestLiana.models — walked via ActiveRecord::Base.descendants —
      # never sees them there in the first place.
      let(:rails_models) do
        if Rails.gem_version >= Gem::Version.new('7.1')
          []
        else
          [ActiveRecord::InternalMetadata, ActiveRecord::SchemaMigration]
        end
      end

      let(:expected_application_models) do
        [
          Address,
          Island,
          Location,
          Manufacturer,
          Owner,
          Product,
          Reference,
          Town,
          Tree,
          User,
          Driver,
          Car,
        ]
      end

      # A real SerializerFactory rebuilds every model's serializer class from scratch, which
      # discards the smart-field attributes any Forest::* collection file attached to the
      # previous generation (that DSL only runs once, when the file is first loaded) — so any
      # example not asserting on serializers still stubs the factory to avoid corrupting the
      # smart fields every other spec in the run relies on.
      it 'should populate the models correctly' do
        allow(ForestLiana::SerializerFactory).to receive(:new)
          .and_return(instance_double(ForestLiana::SerializerFactory, serializer_for: nil))

        ForestLiana::Bootstrapper.new

        expect(ForestLiana.models).to match_array(ForestLiana.models.uniq)
        expect(ForestLiana.models).to include(*rails_models) if rails_models.any?
        expect(application_models).to match_array(expected_application_models)
      end

      it 'should generate serializers for all models' do
        factory = instance_double(ForestLiana::SerializerFactory, serializer_for: nil)
        allow(ForestLiana::SerializerFactory).to receive(:new).and_return(factory)

        ForestLiana::Bootstrapper.new

        expected_application_models.each do |model|
          expect(factory).to have_received(:serializer_for).with(model).once
        end
      end

      it 'should generate controllers for all models' do
        allow(ForestLiana::SerializerFactory).to receive(:new)
          .and_return(instance_double(ForestLiana::SerializerFactory, serializer_for: nil))
        factory = instance_double(ForestLiana::ControllerFactory, controller_for: nil)
        allow(ForestLiana::ControllerFactory).to receive(:new).and_return(factory)

        ForestLiana::Bootstrapper.new

        expected_application_models.each do |model|
          expect(factory).to have_received(:controller_for).with(model).once
        end
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
        allow(ForestLiana::SerializerFactory).to receive(:new)
          .and_return(instance_double(ForestLiana::SerializerFactory, serializer_for: nil))

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
