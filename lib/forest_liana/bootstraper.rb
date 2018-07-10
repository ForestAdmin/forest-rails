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
      namespace_duplicated_models
      create_factories

      if ForestLiana.env_secret
        create_apimap
        require_lib_forest_liana
        format_and_validate_smart_actions

        send_apimap
      end
    end

    private

    def is_sti_parent_model?(model)
      return false unless model.try(:table_exists?)

      model.inheritance_column && model.columns.find { |column| column.name == model.inheritance_column }
    end

    def analyze_model?(model)
      model && model.table_exists? && !SchemaUtils.habtm?(model) &&
        SchemaUtils.model_included?(model)
    end

    def fetch_models
      ActiveRecord::Base.subclasses.each { |model| fetch_model(model) }
    end

    def fetch_model(model)
      begin
        if model.abstract_class?
          model.descendants.each { |submodel| fetch_model(submodel) }
        else
          if is_sti_parent_model?(model)
            model.descendants.each { |submodel_sti| fetch_model(submodel_sti) }
          end

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
      ForestLiana.models.uniq.map do |model|
        ForestLiana::SerializerFactory.new.serializer_for(model)
        ForestLiana::ControllerFactory.new.controller_for(model)
      end

      # Monkey patch the find_serializer_class_name method to specify the
      # good serializer to use.
      ::JSONAPI::Serializer.class_eval do
        def self.find_serializer_class_name(record, options)
          if record.respond_to?(:jsonapi_serializer_class_name)
            record.jsonapi_serializer_class_name.to_s
          else
            ForestLiana::SerializerFactory.get_serializer_name(record.class)
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
          FOREST_LOGGER.error 'Cannot setup properly your Stripe integration.' \
            'Please go to https://doc.forestadmin.com for more information.'
        end
      end

      if intercom_integration?
        if intercom_integration_valid?
          ForestLiana.integrations[:intercom][:mapping] =
            cast_to_array(ForestLiana.integrations[:intercom][:mapping])
          @integration_intercom_valid = true
        else
          FOREST_LOGGER.error 'Cannot setup properly your Intercom integration. ' \
            'Please go to https://doc.forestadmin.com for more information.'
        end
      end

      if mixpanel_integration?
        if mixpanel_integration_valid?
          ForestLiana.integrations[:mixpanel][:mapping] =
            cast_to_array(ForestLiana.integrations[:mixpanel][:mapping])
          @integration_mixpanel_valid = true
        else
          FOREST_LOGGER.error 'Cannot setup properly your Mixpanel integration. ' \
            'Please go to https://doc.forestadmin.com for more information.'
        end
      end
    end

    def namespace_duplicated_models
      ForestLiana.models
        .group_by { |model| model.table_name }
        .select { |table_name, models| models.length > 1 }
        .try(:each) do |table_name, models|
          models.each do |model|
            unless model.name.deconstantize.blank?
              ForestLiana.names_overriden[model] = model.name.gsub('::', '__')
            end
            # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
            ForestLiana.names_old_overriden[model] =
              "#{model.name.deconstantize.downcase}__#{model.table_name}"
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

      if @integration_mixpanel_valid
        ForestLiana.integrations[:mixpanel][:mapping].each do |collection_name|
          setup_mixpanel_integration collection_name
        end
      end
    end

    def require_lib_forest_liana
      path = Rails.root.join('lib', 'forest_liana', '**', '*.rb')
      Dir.glob(File.expand_path(path, __FILE__)).each do |file|
        load file
      end
    end

    def format_and_validate_smart_actions
      ForestLiana.apimap.each do |collection|
        collection.actions.each do |action|
          if action.global
            FOREST_LOGGER.warn "DEPRECATION WARNING: Smart Action \"global\" option is now " \
              "deprecated. Please set \"type: 'global'\" instead of \"global: true\" for the " \
              "\"#{action.name}\" Smart Action."
          end

          if action.type && !['bulk', 'global', 'single'].include?(action.type)
            FOREST_LOGGER.warn "Please set a valid Smart Action type (\"bulk\", \"global\" or " \
              "\"single\") for the \"#{action.name}\" Smart Action."
          end

          if action.fields
            # NOTICE: Set a position to the Smart Actions fields.
            action.fields.each_with_index do |field, index|
              field[:position] = index
            end
          end
        end
      end
    end

    def send_apimap
      if ForestLiana.env_secret && ForestLiana.env_secret.length != 64
        FOREST_LOGGER.error "Your env_secret does not seem to be correct. " \
          "Can you check on Forest that you copied it properly in the " \
          "forest_liana initializer?"
      else
        apimap = JSONAPI::Serializer.serialize(ForestLiana.apimap, {
          is_collection: true,
          include: ['actions', 'segments'],
          meta: {
            liana: 'forest-rails',
            liana_version: liana_version,
            framework_version: Gem.loaded_specs["rails"].version.version,
            orm_version: Gem.loaded_specs["activerecord"].version.version,
            database_type: database_type
          }
        })

        begin
          apimap = ForestLiana::ApimapSorter.new(apimap).perform
          uri = URI.parse("#{forest_url}/forest/apimaps")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if forest_url.start_with?('https')
          http.start do |client|
            request = Net::HTTP::Post.new(uri.path)
            request.body = apimap.to_json
            request['Content-Type'] = 'application/json'
            request['forest-secret-key'] = ForestLiana.env_secret
            response = client.request(request)

            if ['200', '202', '204', '400', '404', '503'].include? response.code
              unless response.body.blank?
                warning = JSON.parse(response.body)['warning']
              end

              if response.is_a?(Net::HTTPNotFound) # NOTICE: HTTP 404 Error
                FOREST_LOGGER.error "Cannot find the project related to the " \
                  "env_secret you configured. Can you check on Forest that " \
                  "you copied it properly in the forest_liana initializer?"
              elsif response.is_a?(Net::HTTPBadRequest) # NOTICE: HTTP 400 Error
                FOREST_LOGGER.error "An error occured with the apimap sent " \
                  "to Forest. Please contact support@forestadmin.com for " \
                  "further investigations."
                elsif response.is_a?(Net::HTTPServiceUnavailable) # NOTICE: HTTP 503 Error
                  FOREST_LOGGER.warn "Forest is in maintenance for a few " \
                    "minutes. We are upgrading your experience in the " \
                    "forest. We just need a few more minutes to get it right."
              elsif warning
                FOREST_LOGGER.warn warning
              end
            else
              FOREST_LOGGER.error "Forest seems to be down right now. Please " \
                "contact support@forestadmin.com for further investigations."
            end
          end
        rescue Errno::ECONNREFUSED, SocketError
          FOREST_LOGGER.warn "Cannot send the apimap to Forest. Are you online?"
        rescue
          FOREST_LOGGER.warn "Cannot send the apimap to Forest. Forest might " \
            "currently be in maintenance."
        end
      end
    end

    def setup_intercom_integration(collection_name)
      model_name = ForestLiana.name_for(collection_name.constantize)
      # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
      model_name_old = ForestLiana.name_old_for(collection_name.constantize)
      collection_display_name = collection_name.capitalize

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_intercom_conversations",
        name_old: "#{model_name_old}_intercom_conversations",
        display_name: collection_display_name + ' Conversations',
        icon: 'intercom',
        integration: 'intercom',
        only_for_relationships: true,
        is_virtual: true,
        is_searchable: false,
        fields: [
          { field: :subject, type: 'String' },
          { field: :body, type: ['String'] },
          { field: :open, type: 'Boolean'},
          { field: :read, type: 'Boolean'},
          { field: :assignee, type: 'String' }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_intercom_attributes",
        name_old: "#{model_name_old}_intercom_attributes",
        display_name: collection_display_name + ' Attributes',
        icon: 'intercom',
        integration: 'intercom',
        only_for_relationships: true,
        is_virtual: true,
        is_searchable: false,
        fields: [
          { field: :created_at, type: 'Date', 'is-filterable': false },
          { field: :updated_at, type: 'Date', 'is-filterable': false },
          { field: :session_count, type: 'Number', 'is-filterable': false },
          { field: :last_seen_ip, type: 'String', 'is-filterable': false },
          { field: :signed_up_at, type: 'Date', 'is-filterable': false },
          { field: :country, type: 'String', 'is-filterable': false },
          { field: :city, type: 'String', 'is-filterable': false },
          { field: :browser, type: 'String', 'is-filterable': false },
          { field: :platform, type: 'String', 'is-filterable': false },
          { field: :companies, type: 'String', 'is-filterable': false },
          { field: :segments, type: 'String', 'is-filterable': false },
          { field: :tags, type: 'String', 'is-filterable': false },
          {
            field: :geoloc,
            type: 'String',
            widget: 'map',
            'is-filterable': false
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
      integration.present? && integration.has_key?(:access_token) && integration.has_key?(:mapping)
    end

    def setup_stripe_integration(collection_name_and_field)
      collection_name = collection_name_and_field.split('.')[0]
      model_name = ForestLiana.name_for(collection_name.constantize)
      # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
      model_name_old = ForestLiana.name_old_for(collection_name.constantize)
      collection_display_name = model_name.capitalize

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_payments",
        name_old: "#{model_name_old}_stripe_payments",
        display_name: collection_display_name + ' Payments',
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', 'is-filterable': false },
          { field: :created, type: 'Date', 'is-filterable': false },
          { field: :amount, type: 'Number', 'is-filterable': false },
          { field: :status, type: 'String', 'is-filterable': false },
          { field: :currency, type: 'String', 'is-filterable': false },
          { field: :refunded, type: 'Boolean', 'is-filterable': false },
          { field: :description, type: 'String', 'is-filterable': false },
          {
            field: :customer,
            type: 'String',
            reference: "#{model_name}.id",
            'is-filterable': false
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
        name_old: "#{model_name_old}_stripe_invoices",
        display_name: collection_display_name + ' Invoices',
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', 'is-filterable': false },
          { field: :amount_due, type: 'Number', 'is-filterable': false },
          { field: :attempt_count, type: 'Number', 'is-filterable': false },
          { field: :attempted, type: 'Boolean', 'is-filterable': false },
          { field: :closed, type: 'Boolean', 'is-filterable': false },
          { field: :currency, type: 'String', 'is-filterable': false },
          { field: :date, type: 'Date', 'is-filterable': false },
          { field: :forgiven, type: 'Boolean', 'is-filterable': false },
          { field: :period_start, type: 'Date', 'is-filterable': false },
          { field: :period_end, type: 'Date', 'is-filterable': false },
          { field: :subtotal, type: 'Number', 'is-filterable': false },
          { field: :total, type: 'Number', 'is-filterable': false },
          { field: :application_fee, type: 'Number', 'is-filterable': false },
          { field: :tax, type: 'Number', 'is-filterable': false },
          { field: :tax_percent, type: 'Number', 'is-filterable': false },
          {
            field: :customer,
            type: 'String',
            reference: "#{model_name}.id",
            'is-filterable': false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_cards",
        name_old: "#{model_name_old}_stripe_cards",
        display_name: collection_display_name + ' Cards',
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        only_for_relationships: true,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', 'is-filterable': false },
          { field: :last4, type: 'String', 'is-filterable': false },
          { field: :brand, type: 'String', 'is-filterable': false },
          { field: :funding, type: 'String', 'is-filterable': false },
          { field: :exp_month, type: 'Number', 'is-filterable': false },
          { field: :exp_year, type: 'Number', 'is-filterable': false },
          { field: :country, type: 'String', 'is-filterable': false },
          { field: :name, type: 'String', 'is-filterable': false },
          { field: :address_line1, type: 'String', 'is-filterable': false },
          { field: :address_line2, type: 'String', 'is-filterable': false },
          { field: :address_city, type: 'String', 'is-filterable': false },
          { field: :address_state, type: 'String', 'is-filterable': false },
          { field: :address_zip, type: 'String', 'is-filterable': false },
          { field: :address_country, type: 'String', 'is-filterable': false },
          { field: :cvc_check, type: 'String', 'is-filterable': false },
          {
            field: :customer,
            type: 'String',
            reference: "#{model_name}.id",
            'is-filterable': false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_subscriptions",
        name_old: "#{model_name_old}_stripe_subscriptions",
        display_name: collection_display_name + ' Subscriptions',
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', 'is-filterable': false },
          { field: :cancel_at_period_end, type: 'Boolean', 'is-filterable': false },
          { field: :canceled_at, type: 'Date', 'is-filterable': false },
          { field: :created, type: 'Date', 'is-filterable': false },
          { field: :current_period_end, type: 'Date', 'is-filterable': false },
          { field: :current_period_start, type: 'Date', 'is-filterable': false },
          { field: :ended_at, type: 'Date', 'is-filterable': false },
          { field: :livemode, type: 'Boolean', 'is-filterable': false },
          { field: :quantity, type: 'Number', 'is-filterable': false },
          { field: :start, type: 'Date', 'is-filterable': false },
          { field: :status, type: 'String', 'is-filterable': false },
          { field: :tax_percent, type: 'Number', 'is-filterable': false },
          { field: :trial_end, type: 'Date', 'is-filterable': false },
          { field: :trial_start, type: 'Date', 'is-filterable': false },
          {
            field: :customer,
            type: 'String',
            reference: "#{model_name}.id",
            'is-filterable': false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_bank_accounts",
        name_old: "#{model_name_old}_stripe_bank_accounts",
        display_name: collection_display_name + ' Bank Accounts',
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        only_for_relationships: true,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', 'is-filterable': false },
          { field: :account, type: 'String', 'is-filterable': false },
          { field: :account_holder_name, type: 'String', 'is-filterable': false },
          { field: :account_holder_type, type: 'String', 'is-filterable': false },
          { field: :bank_name, type: 'String', 'is-filterable': false },
          { field: :country, type: 'String', 'is-filterable': false },
          { field: :currency, type: 'String', 'is-filterable': false },
          { field: :default_for_currency, type: 'Boolean', 'is-filterable': false },
          { field: :fingerprint, type: 'String', 'is-filterable': false },
          { field: :last4, type: 'String', 'is-filterable': false },
          { field: :rooting_number, type: 'String', 'is-filterable': false },
          { field: :status, type: 'String', 'is-filterable': false },
          {
            field: :customer,
            type: 'String',
            reference: "#{model_name}.id",
            'is-filterable': false
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

    def setup_mixpanel_integration(collection_name_and_field)
      collection_name = collection_name_and_field.split('.')[0]
      model_name = ForestLiana.name_for(collection_name.constantize)
      collection_display_name = model_name.capitalize

      field_attributes = { 'is-filterable': false , 'is-virtual': true, 'is-sortable': false }

      fields = [
        { field: :id, type: 'String' },
        { field: :event, type: 'String' },
        { field: :date, type: 'Date' },
        { field: :city, type: 'String' },
        { field: :region, type: 'String' },
        { field: :country, type: 'String' },
        { field: :timezone, type: 'String' },
        { field: :os, type: 'String' },
        { field: :osVersion, type: 'String' },
        { field: :browser, type: 'String' },
        { field: :browserVersion, type: 'String' },
      ]

      fields = fields.map { |field| field.merge(field_attributes) }

      custom_properties = ForestLiana.integrations[:mixpanel][:custom_properties]
      custom_properties = custom_properties.map { |property|
        { field: property.to_sym, type: 'String' }.merge(field_attributes)
      }

      fields = fields.concat(custom_properties)

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_mixpanel_events",
        display_name: "#{collection_display_name} Events",
        icon: 'mixpanel',
        integration: 'mixpanel',
        is_virtual: true,
        is_read_only: true,
        only_for_relationships: true,
        pagination_type: 'cursor',
        fields: fields
      })
    end

    def mixpanel_integration?
      ForestLiana.integrations
        .try(:[], :mixpanel)
        .present?
    end

    def mixpanel_integration_valid?
      integration = ForestLiana.integrations.try(:[], :mixpanel)
      integration.present? && integration.has_key?(:api_secret) &&
      integration.has_key?(:mapping)
    end

    def forest_url
      ENV['FOREST_URL'] || 'https://api.forestadmin.com';
    end

    def liana_version
      Gem::Specification.find_all_by_name('forest_liana')
        .try(:first)
        .try(:version)
        .try(:to_s)
    end

    def database_type
      begin
        connection = ActiveRecord::Base.connection
        if connection.try(:config)
          connection.config[:adapter]
        else
          connection.instance_values['config'][:adapter]
        end
      rescue
        'unknown'
      end
    end
  end
end
