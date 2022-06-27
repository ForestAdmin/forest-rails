require_relative 'schema_file_updater'
require_relative 'version'

module ForestLiana
  class Bootstrapper
    SCHEMA_FILENAME = File.join(Dir.pwd, '.forestadmin-schema.json')

    def initialize
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

      unless Rails.application.config.action_controller.perform_caching || Rails.env.test? || ForestLiana.forest_client_id
        FOREST_LOGGER.error "You need to enable caching on your environment to use Forest Admin.\n" \
          "For a development environment, run: `rails dev:cache`\n" \
          "Or setup a static forest_client_id by following this part of the documentation:\n" \
          "https://docs.forestadmin.com/documentation/how-tos/maintain/upgrade-notes-rails/upgrade-to-v6#setup-a-static-clientid"
      end

      fetch_models
      check_integrations_setup
      namespace_duplicated_models
      create_factories

      generate_apimap if ForestLiana.env_secret
    end

    def synchronize(with_feedback=false)
      send_apimap(with_feedback) if ForestLiana.env_secret
    end

    def display_apimap
      if ForestLiana.env_secret
        puts " = Current Forest Apimap:\n#{JSON.pretty_generate(get_apimap_serialized)}"
      end
    end

    private

    def get_collection(collection_name)
      ForestLiana.apimap.find { |collection| collection.name.to_s == collection_name }
    end

    def get_action(collection, action_name)
      collection.actions.find {|action| action.name == action_name}
    end

    def generate_action_hooks()
      @collections_sent.each do |collection|
        collection['actions'].each do |action|
          c = get_collection(collection['name'])
          unless c.nil?
            a = get_action(c, action['name'])
            load = !a.nil? && !a.hooks.nil? && a.hooks.key?(:load) && a.hooks[:load].is_a?(Proc)
            change = !a.nil? && !a.hooks.nil? && a.hooks.key?(:change) && a.hooks[:change].is_a?(Hash) ? a.hooks[:change].keys : []
            action['hooks'] = {'load' => load, 'change' => change}
          end
        end
      end
    end

    def generate_apimap
      create_apimap
      require_lib_forest_liana
      format_and_validate_smart_actions

      if Rails.env.development?
        @collections_sent = ForestLiana.apimap.as_json
        @meta_sent = ForestLiana.meta
        generate_action_hooks
        SchemaFileUpdater.new(SCHEMA_FILENAME, @collections_sent, @meta_sent).perform()
      else
        if File.exists?(SCHEMA_FILENAME)
          begin
            content = JSON.parse(File.read(SCHEMA_FILENAME))
            @collections_sent = content['collections']
            @meta_sent = content['meta']
            generate_action_hooks
          rescue JSON::JSONError => error
            FOREST_REPORTER.report error
            FOREST_LOGGER.error "The content of .forestadmin-schema.json file is not a correct JSON."
            FOREST_LOGGER.error "The schema cannot be synchronized with Forest Admin servers."
          end
        else
          FOREST_LOGGER.error "The .forestadmin-schema.json file does not exist."
          FOREST_LOGGER.error "The schema cannot be synchronized with Forest Admin servers."
        end
      end
    end

    def analyze_model?(model)
      model && model.table_exists? && !SchemaUtils.habtm?(model) &&
        SchemaUtils.model_included?(model)
    end

    def fetch_models
      ActiveRecord::Base.descendants.each { |model| fetch_model(model) }
    end

    def fetch_model(model)
      return if model.abstract_class?
      return if ForestLiana.models.include?(model)
      return unless analyze_model?(model)

      ForestLiana.models << model
    rescue => exception
      FOREST_REPORTER.report exception
      FOREST_LOGGER.error "Cannot fetch properly model #{model.name}:\n" \
          "#{exception}"
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
      ::ForestAdmin::JSONAPI::Serializer.class_eval do
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

    def setup_forest_liana_meta
      ForestLiana.meta = {
        liana: 'forest-rails',
        liana_version: ForestLiana::VERSION,
        stack: {
           database_type: database_type,
           orm_version: Gem.loaded_specs["activerecord"].version.version,
        }
      }
    end

    def create_apimap
      setup_forest_liana_meta

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
      Dir.glob(ForestLiana.config_dir).each do |file|
        load file
      end
    end

    def format_and_validate_smart_actions
      ForestLiana.apimap.each do |collection|
        collection.actions.each do |action|
          if action.fields
            # NOTICE: Set a position to the Smart Actions fields.
            action.fields.each_with_index do |field, index|
              field[:position] = index
            end
          end
        end
      end
    end

    def get_apimap_serialized
      serializer = ForestLiana::SchemaSerializer.new(@collections_sent, @meta_sent)
      apimap = serializer.serialize
      ForestLiana::ApimapSorter.new(apimap).perform
    end

    def send_apimap(with_feedback=false)
      if ForestLiana.env_secret && ForestLiana.env_secret.length != 64
        FOREST_LOGGER.error "Your env_secret does not seem to be correct. " \
          "Can you check on Forest that you copied it properly in the " \
          "forest_liana initializer?"
      else
        apimap = get_apimap_serialized

        begin
          puts " = Sending Forest Apimap:\n#{JSON.pretty_generate(apimap)}" if with_feedback
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

              if with_feedback
                if response.is_a?(Net::HTTPOK) || response.is_a?(Net::HTTPNoContent)
                  puts " = Apimap Received - nothing changed"
                elsif response.is_a?(Net::HTTPAccepted)
                  puts " = Apimap Received - update detected (currently updating the UI)"
                end
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

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_intercom_conversations",
        name_old: "#{model_name_old}_intercom_conversations",
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
        icon: 'intercom',
        integration: 'intercom',
        only_for_relationships: true,
        is_virtual: true,
        is_searchable: false,
        fields: [
          { field: :created_at, type: 'Date', is_filterable: false },
          { field: :updated_at, type: 'Date', is_filterable: false },
          { field: :session_count, type: 'Number', is_filterable: false },
          { field: :last_seen_ip, type: 'String', is_filterable: false },
          { field: :signed_up_at, type: 'Date', is_filterable: false },
          { field: :country, type: 'String', is_filterable: false },
          { field: :city, type: 'String', is_filterable: false },
          { field: :browser, type: 'String', is_filterable: false },
          { field: :platform, type: 'String', is_filterable: false },
          { field: :companies, type: 'String', is_filterable: false },
          { field: :segments, type: 'String', is_filterable: false },
          { field: :tags, type: 'String', is_filterable: false },
          {
            field: :geoloc,
            type: 'String',
            widget: 'map',
            is_filterable: false
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

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_payments",
        name_old: "#{model_name_old}_stripe_payments",
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', is_filterable: false },
          { field: :created, type: 'Date', is_filterable: false },
          { field: :amount, type: 'Number', is_filterable: false },
          { field: :status, type: 'String', is_filterable: false },
          { field: :currency, type: 'String', is_filterable: false },
          { field: :refunded, type: 'Boolean', is_filterable: false },
          { field: :description, type: 'String', is_filterable: false },
          {
            field: :customer,
            type: 'String',
            relationship: 'BelongsTo',
            reference: "#{model_name}.id",
            is_filterable: false
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
        name: "#{model_name}_stripe_invoices",
        name_old: "#{model_name_old}_stripe_invoices",
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', is_filterable: false },
          { field: :amount_due, type: 'Number', is_filterable: false },
          { field: :amount_paid, type: 'Number', is_filterable: false },
          { field: :amount_remaining, type: 'Number', is_filterable: false },
          { field: :application_fee_amount, type: 'Number', is_filterable: false },
          { field: :attempt_count, type: 'Number', is_filterable: false },
          { field: :attempted, type: 'Boolean', is_filterable: false },
          { field: :currency, type: 'String', is_filterable: false },
          { field: :due_date, type: 'Date', is_filterable: false },
          { field: :period_start, type: 'Date', is_filterable: false },
          { field: :period_end, type: 'Date', is_filterable: false },
          { field: :status, type: 'String', enums: ['draft', 'open', 'paid', 'uncollectible', 'void'], is_filterable: false },
          { field: :subtotal, type: 'Number', is_filterable: false },
          { field: :total, type: 'Number', is_filterable: false },
          { field: :tax, type: 'Number', is_filterable: false },
          {
            field: :customer,
            type: 'String',
            relationship: 'BelongsTo',
            reference: "#{model_name}.id",
            is_filterable: false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_cards",
        name_old: "#{model_name_old}_stripe_cards",
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        only_for_relationships: true,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', is_filterable: false },
          { field: :last4, type: 'String', is_filterable: false },
          { field: :brand, type: 'String', is_filterable: false },
          { field: :funding, type: 'String', is_filterable: false },
          { field: :exp_month, type: 'Number', is_filterable: false },
          { field: :exp_year, type: 'Number', is_filterable: false },
          { field: :country, type: 'String', is_filterable: false },
          { field: :name, type: 'String', is_filterable: false },
          { field: :address_line1, type: 'String', is_filterable: false },
          { field: :address_line2, type: 'String', is_filterable: false },
          { field: :address_city, type: 'String', is_filterable: false },
          { field: :address_state, type: 'String', is_filterable: false },
          { field: :address_zip, type: 'String', is_filterable: false },
          { field: :address_country, type: 'String', is_filterable: false },
          { field: :cvc_check, type: 'String', is_filterable: false },
          {
            field: :customer,
            type: 'String',
            relationship: 'BelongsTo',
            reference: "#{model_name}.id",
            is_filterable: false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_subscriptions",
        name_old: "#{model_name_old}_stripe_subscriptions",
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', is_filterable: false },
          { field: :cancel_at_period_end, type: 'Boolean', is_filterable: false },
          { field: :canceled_at, type: 'Date', is_filterable: false },
          { field: :created, type: 'Date', is_filterable: false },
          { field: :current_period_end, type: 'Date', is_filterable: false },
          { field: :current_period_start, type: 'Date', is_filterable: false },
          { field: :ended_at, type: 'Date', is_filterable: false },
          { field: :livemode, type: 'Boolean', is_filterable: false },
          { field: :quantity, type: 'Number', is_filterable: false },
          { field: :start, type: 'Date', is_filterable: false },
          { field: :status, type: 'String', is_filterable: false },
          { field: :tax_percent, type: 'Number', is_filterable: false },
          { field: :trial_end, type: 'Date', is_filterable: false },
          { field: :trial_start, type: 'Date', is_filterable: false },
          {
            field: :customer,
            type: 'String',
            relationship: 'BelongsTo',
            reference: "#{model_name}.id",
            is_filterable: false
          }
        ]
      })

      ForestLiana.apimap << ForestLiana::Model::Collection.new({
        name: "#{model_name}_stripe_bank_accounts",
        name_old: "#{model_name_old}_stripe_bank_accounts",
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        only_for_relationships: true,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', is_filterable: false },
          { field: :account, type: 'String', is_filterable: false },
          { field: :account_holder_name, type: 'String', is_filterable: false },
          { field: :account_holder_type, type: 'String', is_filterable: false },
          { field: :bank_name, type: 'String', is_filterable: false },
          { field: :country, type: 'String', is_filterable: false },
          { field: :currency, type: 'String', is_filterable: false },
          { field: :default_for_currency, type: 'Boolean', is_filterable: false },
          { field: :fingerprint, type: 'String', is_filterable: false },
          { field: :last4, type: 'String', is_filterable: false },
          { field: :rooting_number, type: 'String', is_filterable: false },
          { field: :status, type: 'String', is_filterable: false },
          {
            field: :customer,
            type: 'String',
            relationship: 'BelongsTo',
            reference: "#{model_name}.id",
            is_filterable: false
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

      field_attributes = { is_filterable: false , is_virtual: true, is_sortable: false }

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
      ENV['FOREST_URL'] || 'https://api.forestadmin.com'
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
