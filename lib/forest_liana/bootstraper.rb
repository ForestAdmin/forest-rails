module ForestLiana
  class Bootstraper

    def initialize(app)
      @app = app
      @logger = Logger.new(STDOUT)
    end

    def perform
      create_serializers

      if ForestLiana.jwt_signing_key
        create_apimap
        send_apimap
      end
    end

    private

    def create_serializers
      SchemaUtils.tables_names.map do |table_name|
        model = SchemaUtils.find_model_from_table_name(table_name)
        SerializerFactory.new.serializer_for(model) if \
          model.try(:table_exists?)
      end

      # Monkey patch the find_serializer_class_name method to specify the
      # good serializer to use.
      JSONAPI::Serializer.class_eval do
        def self.find_serializer_class_name(obj)
          SerializerFactory.get_serializer_name(obj.class)
        end
      end
    end

    def create_apimap
      SchemaUtils.tables_names.map do |table_name|
        model = SchemaUtils.find_model_from_table_name(table_name)
        if model.try(:table_exists?)
          ForestLiana.apimap << SchemaAdapter.new(model).perform
        end
      end

      Dir["#{@app.root}/app/models/forest/*.rb"].each {|file| require file }

      setup_stripe_integration if stripe_integration?
      setup_intercom_integration if intercom_integration?
    end

    def send_apimap
      json = JSONAPI::Serializer.serialize(ForestLiana.apimap, {
        is_collection: true,
        include: ['actions'],
        meta: { liana: 'forest-rails', liana_version: liana_version }
      })

      uri = URI.parse("#{forest_url}/forest/apimaps")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if forest_url.start_with?('https')
      http.start do |client|
        request = Net::HTTP::Post.new(uri.path)
        request.body = json.to_json
        request['Content-Type'] = 'application/json'
        request['forest-secret-key'] = ForestLiana.jwt_signing_key
        response = client.request(request)

        if response.is_a?(Net::HTTPNotFound)
          logger.warn "Forest cannot find your project secret key. " \
            "Please, run `rails g forest_liana:install`."
        end
      end
    end

    def setup_intercom_integration
      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: 'intercom_conversations',
        only_for_relationships: true,
        is_virtual: true,
        fields: [
          { field: :subject, type: 'String' },
          { field: :body, type: ['String'], widget: 'link' },
          { field: :open, type: 'Boolean'},
          { field: :read, type: 'Boolean'},
          { field: :assignee, type: 'String' }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: 'intercom_attributes',
        only_for_relationships: true,
        is_virtual: true,
        fields: [
          { field: :created_at, type: 'Date', is_searchable: false },
          { field: :updated_at, type: 'Date', is_searchable: false  },
          { field: :session_count, type: 'Number', is_searchable: false  },
          { field: :last_seen_ip, type: 'String', is_searchable: false  },
          { field: :signed_up_at, type: 'Date', is_searchable: false  },
          { field: :country, type: 'String', is_searchable: false  },
          { field: :city, type: 'String', is_searchable: false  },
          { field: :browser, type: 'String', is_searchable: false  },
          { field: :platform, type: 'String', is_searchable: false  },
          { field: :companies, type: 'String', is_searchable: false  },
          { field: :segments, type: 'String', is_searchable: false  },
          { field: :tags, type: 'String', is_searchable: false  },
          {
            field: :geoloc,
            type: 'String',
            widget: 'google map',
            is_searchable: false
          }
        ]
      })
    end

    def intercom_integration?
      ForestLiana.integrations
        .try(:[], :intercom)
        .try(:[], :user_collection)
        .present?
    end

    def setup_stripe_integration
      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: 'stripe_payments',
        is_virtual: true,
        is_read_only: true,
        fields: [
          { field: :id, type: 'String', is_searchable: false },
          { field: :created, type: 'Date', is_searchable: false },
          { field: :amount, type: 'Number', is_searchable: false },
          { field: :status, type: 'String', is_searchable: false },
          { field: :currency, type: 'String', is_searchable: false },
          { field: :refunded, type: 'Boolean', is_searchable: false },
          { field: :description, type: 'String', is_searchable: false },
          {
            field: :customer,
            type: 'String',
            reference: 'customers.id',
            is_searchable: false
          }
        ],
        actions: [
          ForestLiana::Model::Action.new({
            name: 'Refund',
            endpoint: '/forest/stripe_payments/refunds'
          })
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: 'stripe_invoices',
        is_virtual: true,
        is_read_only: true,
        fields: [
          { field: :id, type: 'String', is_searchable: false },
          { field: :amount_due, type: 'Number', is_searchable: false },
          { field: :attempt_count, type: 'Number', is_searchable: false },
          { field: :attempted, type: 'Boolean', is_searchable: false },
          { field: :closed, type: 'Boolean', is_searchable: false },
          { field: :currency, type: 'String', is_searchable: false },
          { field: :date, type: 'Date', is_searchable: false },
          { field: :forgiven, type: 'Boolean', is_searchable: false },
          { field: :period_start, type: 'Date', is_searchable: false },
          { field: :period_end, type: 'Date', is_searchable: false },
          { field: :subtotal, type: 'Number', is_searchable: false },
          { field: :total, type: 'Number', is_searchable: false },
          { field: :application_fee, type: 'Number', is_searchable: false },
          { field: :tax, type: 'Number', is_searchable: false },
          { field: :tax_percent, type: 'Number', is_searchable: false },
          {
            field: :customer,
            type: 'String',
            reference: 'customers.id',
            is_searchable: false
          }
        ],
        actions: [
          ForestLiana::Model::Action.new({
            name: 'Refund',
            endpoint: '/forest/stripe_payments/refunds'
          })
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: 'stripe_cards',
        is_virtual: true,
        is_read_only: true,
        only_for_relationships: true,
        fields: [
          { field: :id, type: 'String', is_searchable: false },
          { field: :last4, type: 'String', is_searchable: false },
          { field: :brand, type: 'String', is_searchable: false },
          { field: :funding, type: 'String', is_searchable: false },
          { field: :exp_month, type: 'Number', is_searchable: false },
          { field: :exp_year, type: 'Number', is_searchable: false },
          { field: :country, type: 'String', is_searchable: false },
          { field: :name, type: 'String', is_searchable: false },
          { field: :address_line1, type: 'String', is_searchable: false },
          { field: :address_line2, type: 'String', is_searchable: false },
          { field: :address_city, type: 'String', is_searchable: false },
          { field: :address_state, type: 'String', is_searchable: false },
          { field: :address_zip, type: 'String', is_searchable: false },
          { field: :address_country, type: 'String', is_searchable: false },
          { field: :cvc_check, type: 'String', is_searchable: false },
          {
            field: :customer,
            type: 'String',
            reference: 'customers.id',
            is_searchable: false
          }
        ]
      })
    end

    def stripe_integration?
      ForestLiana.integrations
        .try(:[], :stripe)
        .try(:[], :api_key)
        .present?
    end

    def forest_url
      ENV['FOREST_URL'] || 'https://forestadmin-server.herokuapp.com';
    end

    def liana_version
      Gem::Specification.find_all_by_name('forest_liana')
        .try(:first)
        .try(:version)
        .try(:to_s)
    end
  end
end
