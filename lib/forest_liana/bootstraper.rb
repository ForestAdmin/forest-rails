module ForestLiana
  class Bootstraper

    def initialize(app)
      @app = app

      @integration_stripe_valid = false
      @integration_intercom_valid = false

      if ForestLiana.secret_key && ForestLiana.auth_key
        FOREST_LOGGER.warn "DEPRECATION WARNING: The use of " \
          "ForestLiana.secret_key and ForestLiana.auth_key " \
          "(config/initializers/forest_liana.rb) is deprecated. Please use " \
          "ForestLiana.env_secret and ForestLiana.auth_secret instead."
        ForestLiana.env_secret = ForestLiana.secret_key
        ForestLiana.auth_secret = ForestLiana.auth_key
      end
    end

    def perform
      fetch_models
      check_integrations_setup
      create_factories

      if ForestLiana.env_secret
        create_apimap
        require_lib_forest_liana
        send_apimap
      end
    end

    private

    def analyze_model?(model)
      return model && model.table_exists? && !SchemaUtils.habtm?(model) &&
        SchemaUtils.model_included?(model) && !SchemaUtils.sti_child?(model)
    end

    def fetch_models
      ActiveRecord::Base.subclasses.each { |model| fetch_model(model) }
    end

    def fetch_model(model)
      begin
        if model.abstract_class?
          model.descendants.each { |submodel| fetch_model(submodel) }
        else
          if analyze_model?(model)
            ForestLiana.models << model
          end
        end
      rescue => exception
        FOREST_LOGGER.error "Cannot fetch properly model #{model.name}:\n" \
          "#{exception}"
      end
    end

    def cast_to_array value
      value.is_a?(String) ? [value] : value
    end

    def create_factories
      ForestLiana.models.map do |model|
        ForestLiana::SerializerFactory.new.serializer_for(model)
        ForestLiana::ControllerFactory.new.controller_for(model)
      end

      # Monkey patch the find_serializer_class_name method to specify the
      # good serializer to use.
      ::JSONAPI::Serializer.class_eval do
        def self.find_serializer_class_name(obj, options)
          if obj.respond_to?(:jsonapi_serializer_class_name)
            obj.jsonapi_serializer_class_name.to_s
          else
            ForestLiana::SerializerFactory.get_serializer_name(obj.class)
          end
        end
      end
    end

    def check_integrations_setup
      if stripe_integration?
        if stripe_integration_valid? || stripe_integration_deprecated?
          ForestLiana.integrations[:stripe][:mapping] =
            cast_to_array(ForestLiana.integrations[:stripe][:mapping])
          @integration_stripe_valid = true
        else
          FOREST_LOGGER.error 'Cannot setup properly your Stripe integration.'
        end
      end

      if intercom_integration?
        if intercom_integration_valid? || intercom_integration_deprecated?
          ForestLiana.integrations[:intercom][:mapping] =
            cast_to_array(ForestLiana.integrations[:intercom][:mapping])
          @integration_intercom_valid = true
        else
          FOREST_LOGGER.error 'Cannot setup properly your Intercom integration.'
        end
      end
    end

    def create_apimap
      ForestLiana.models.map do |model|
        if analyze_model?(model)
          SchemaAdapter.new(model).perform
        end
      end

      if @integration_stripe_valid
        ForestLiana.integrations[:stripe][:mapping].each do |collection|
          setup_stripe_integration collection
        end
      end

      if @integration_intercom_valid
        ForestLiana.integrations[:intercom][:mapping].each do |collection_name|
          setup_intercom_integration collection_name
        end
      end
    end

    def require_lib_forest_liana
      path = Rails.root.join('lib', 'forest_liana', '**', '*.rb')
      Dir.glob(File.expand_path(path, __FILE__)).each do |file|
        load file
      end
    end

    def send_apimap
      if ForestLiana.env_secret && ForestLiana.env_secret.length != 64
        FOREST_LOGGER.error "Your env_secret does not seem to be correct. " \
          "Can you check on Forest that you copied it properly in the " \
          "forest_liana initializer?"
      else
        json = JSONAPI::Serializer.serialize(ForestLiana.apimap, {
          is_collection: true,
          include: ['actions', 'segments'],
          meta: { liana: 'forest-rails', liana_version: liana_version }
        })

        begin
          uri = URI.parse("#{forest_url}/forest/apimaps")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if forest_url.start_with?('https')
          http.start do |client|
            request = Net::HTTP::Post.new(uri.path)
            request.body = json.to_json
            request['Content-Type'] = 'application/json'
            request['forest-secret-key'] = ForestLiana.env_secret
            response = client.request(request)

            unless response.body.blank?
              warning = JSON.parse(response.body)['warning']
            end

            if response.is_a?(Net::HTTPNotFound) # NOTICE: HTTP 404 Error
              FOREST_LOGGER.error "Cannot find the project related to the " \
                "env_secret you configured. Can you check on Forest that you " \
                "copied it properly in the forest_liana initializer?"
            elsif response.is_a?(Net::HTTPBadRequest) # NOTICE: HTTP 400 Error
              FOREST_LOGGER.error "An error occured with the apimap sent to " \
                "Forest. Please contact support@forestadmin.com for further " \
                "investigations."
            elsif warning
              FOREST_LOGGER.warn warning
            end
          end
        rescue Errno::ECONNREFUSED
          FOREST_LOGGER.warn "Cannot send the apimap to Forest. Are you online?"
        end
      end
    end

    def setup_intercom_integration(collection_name)
      model_name = collection_name.constantize.try(:table_name)
      collection_display_name = collection_name.capitalize

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_intercom_conversations",
        display_name: collection_display_name + ' Conversations',
        icon: 'intercom',
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
        name: "#{model_name}_intercom_attributes",
        display_name: collection_display_name + ' Attributes',
        icon: 'intercom',
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
        .present?
    end

    def intercom_integration_valid?
      integration = ForestLiana.integrations.try(:[], :intercom)
      integration.present? && integration.has_key?(:api_key) &&
        integration.has_key?(:app_id) && integration.has_key?(:mapping)
    end

    def intercom_integration_deprecated?
      integration = ForestLiana.integrations.try(:[], :intercom)

      is_deprecated = integration.present? && integration.has_key?(:api_key) &&
        integration.has_key?(:app_id) && integration.has_key?(:user_collection)

      if is_deprecated
        integration[:mapping] = integration[:user_collection]

        FOREST_LOGGER.warn "Intercom integration attribute \"user_collection\"" \
          "is now deprecated, please use \"mapping\" attribute."
      end

      is_deprecated
    end

    def setup_stripe_integration(collection_name_and_field)
      collection_name = collection_name_and_field.split('.')[0]
      model_name = collection_name.constantize.try(:table_name)
      collection_display_name = model_name.capitalize

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_payments",
        display_name: collection_display_name + ' Payments',
        icon: 'stripe',
        is_virtual: true,
        is_read_only: true,
        pagination_type: 'cursor',
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
            reference: "#{model_name}.id",
            is_searchable: false
          }
        ],
        actions: [
          ForestLiana::Model::Action.new({
            id: 'stripe.Refund',
            name: 'Refund',
            endpoint: '/forest/stripe_payments/refunds'
          })
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_invoices",
        display_name: collection_display_name + ' Invoices',
        icon: 'stripe',
        is_virtual: true,
        is_read_only: true,
        pagination_type: 'cursor',
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
            reference: "#{model_name}.id",
            is_searchable: false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_cards",
        display_name: collection_display_name + ' Cards',
        icon: 'stripe',
        is_virtual: true,
        is_read_only: true,
        only_for_relationships: true,
        pagination_type: 'cursor',
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
            reference: "#{model_name}.id",
            is_searchable: false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_subscriptions",
        display_name: collection_display_name + ' Subscriptions',
        icon: 'stripe',
        is_virtual: true,
        is_read_only: true,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', is_searchable: false },
          { field: :cancel_at_period_end, type: 'Boolean', is_searchable: false },
          { field: :canceled_at, type: 'Date', is_searchable: false },
          { field: :created, type: 'Date', is_searchable: false },
          { field: :current_period_end, type: 'Date', is_searchable: false },
          { field: :current_period_start, type: 'Date', is_searchable: false },
          { field: :ended_at, type: 'Date', is_searchable: false },
          { field: :livemode, type: 'Boolean', is_searchable: false },
          { field: :quantity, type: 'Number', is_searchable: false },
          { field: :start, type: 'Date', is_searchable: false },
          { field: :status, type: 'String', is_searchable: false },
          { field: :tax_percent, type: 'Number', is_searchable: false },
          { field: :trial_end, type: 'Date', is_searchable: false },
          { field: :trial_start, type: 'Date', is_searchable: false },
          {
            field: :customer,
            type: 'String',
            reference: "#{model_name}.id",
            is_searchable: false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_bank_accounts",
        display_name: collection_display_name + ' Bank Accounts',
        icon: 'stripe',
        is_virtual: true,
        is_read_only: true,
        only_for_relationships: true,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', is_searchable: false },
          { field: :account, type: 'String', is_searchable: false },
          { field: :account_holder_name, type: 'String', is_searchable: false },
          { field: :account_holder_type, type: 'String', is_searchable: false },
          { field: :bank_name, type: 'String', is_searchable: false },
          { field: :country, type: 'String', is_searchable: false },
          { field: :currency, type: 'String', is_searchable: false },
          { field: :default_for_currency, type: 'Boolean', is_searchable: false },
          { field: :fingerprint, type: 'String', is_searchable: false },
          { field: :last4, type: 'String', is_searchable: false },
          { field: :rooting_number, type: 'String', is_searchable: false },
          { field: :status, type: 'String', is_searchable: false },
          {
            field: :customer,
            type: 'String',
            reference: "#{model_name}.id",
            is_searchable: false
          }
        ]
      })
    end

    def stripe_integration?
      ForestLiana.integrations
        .try(:[], :stripe)
        .present?
    end

    def stripe_integration_valid?
      integration = ForestLiana.integrations.try(:[], :stripe)
      integration.present? && integration.has_key?(:api_key) &&
        integration.has_key?(:mapping)
    end

    def stripe_integration_deprecated?
      integration = ForestLiana.integrations.try(:[], :stripe)
      is_deprecated = integration.present? && integration.has_key?(:api_key) &&
        integration.has_key?(:user_collection) &&
        integration.has_key?(:user_field)

      if is_deprecated
        integration[:mapping] =
          "#{integration[:user_collection]}.#{integration[:user_field]}"

        FOREST_LOGGER.warn "Stripe integration attributes \"user_collection\" and " \
          "\"user_field\" are now deprecated, please use \"mapping\" attribute."
      end

      is_deprecated
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
