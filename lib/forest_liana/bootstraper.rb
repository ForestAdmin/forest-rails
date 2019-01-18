module ForestLiana
  class Bootstraper

    def initialize
      @integration_stripe_valid = false
      @integration_intercom_valid = false
      @collection_keys_whitelist = [
        'name',
        'name_old',
        'icon',
        'integration',
        'is_read_only',
        'is_searchable',
        'is_virtual',
        'only_for_relationships',
        'pagination_type',
        'fields',
        'segments',
        'actions',
      ]
      @field_keys_whitelist = [
        'field',
        'type',
        'default_value',
        'enums',
        'integration',
        'is_filterable',
        'is_read_only',
        'is_required',
        'is_sortable',
        'is_virtual',
        'reference',
        'inverse_of',
        'relationship',
        'widget',
        'validations',
      ]
      @validation_keys_whitelist = [
        'message',
        'type',
        'value',
      ],
      @action_keys_whitelist = [
        'name',
        'type',
        'base_url',
        'endpoint',
        'http_method',
        'redirect',
        'download',
        'fields',
      ]
      @action_field_keys_whitelist = [
        'name',
        'type',
        'is_required',
        'default_value',
        'description',
        'reference',
        'enums',
        'widget',
      ]
      @segment_keys_whitelist = ['name']

      if ForestLiana.secret_key && ForestLiana.auth_key
        FOREST_LOGGER.warn "DEPRECATION WARNING: The use of " \
          "ForestLiana.secret_key and ForestLiana.auth_key " \
          "(config/initializers/forest_liana.rb) is deprecated. Please use " \
          "ForestLiana.env_secret and ForestLiana.auth_secret instead."
        ForestLiana.env_secret = ForestLiana.secret_key
        ForestLiana.auth_secret = ForestLiana.auth_key
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

    def generate_apimap
      create_apimap
      unless Rails.env.development?
        load_apimap
      end

      require_lib_forest_liana
      format_and_validate_smart_actions

      if Rails.env.development?
        update_schema_file
      end
    end

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

    def setup_forest_liana_meta
      ForestLiana.meta = {
        database_type: database_type,
        framework_version: Gem.loaded_specs["rails"].version.version,
        liana: 'forest-rails',
        liana_version: liana_version,
        orm_version: Gem.loaded_specs["activerecord"].version.version
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

    def diff_active_record(record_a, record_b)
      (record_a.attributes.to_a - record_b.attributes.to_a).map(&:first)
    end

    def load_apimap
      if File.exists?(File.join(Rails.root, '.forestadmin-schema.json'))
        begin
          apimap = File.read(File.join(Rails.root, '.forestadmin-schema.json'))
          apimap = JSON.parse(apimap)
          old_collections = ForestLiana.apimap
          ForestLiana.meta = apimap['meta']
          collections = ForestLiana::Model::Collection.from_json(apimap['collections'])

          collections.each do |new_collection|
            old_collection = old_collections.detect { |collection| collection.name == new_collection.name }

            next if old_collection.nil?
            changed_keys = diff_active_record(new_collection, old_collection)
            changed_keys.each do |changed_key|
              case changed_key
              when "actions"
                if new_collection.actions.length
                  new_collection.actions.each do |new_action|
                    old_action = old_collection.actions.detect { |action| action.name == new_action.name }

                    unless old_action.nil?
                      action_changed_keys = diff_active_record(new_action, old_action)
                      action_changed_keys = action_changed_keys.select { |action_changed_key| !@action_keys_whitelist.include?(action_changed_key) }
                      action_changed_keys.each { |action_changed_key| new_action.send("#{action_changed_key}=", old_action.send(action_changed_key)) }
                    end
                  end
                end
              when "segments"
                if new_collection.segments.length
                  new_collection.segments.each do |new_segment|
                    old_segment = old_collection.segments.detect { |segment| segment.name == new_segment.name }

                    unless old_segment.nil?
                      segment_changed_keys = diff_active_record(new_segment, old_segment)
                      segment_changed_keys = segment_changed_keys.select { |segment_changed_key| !@segment_keys_whitelist.include?(segment_changed_key) }
                      segment_changed_keys.each { |segment_changed_key| new_segment.send("#{segment_changed_key}=", old_segment.send(segment_changed_key)) }
                    end
                  end
                end
              when "fields"
                if new_collection.fields.length
                  new_collection.fields.each do |new_field|
                    old_field = old_collection.fields.detect { |field| field[:field] == new_field[:field] }

                    unless old_field.nil?
                      field_changed_keys = old_field.reject { |key, _| @field_keys_whitelist.include?(key) }.keys
                      field_changed_keys.each { |field_changed_key| new_field[field_changed_key] = old_field[field_changed_key] }
                    end
                  end
                end
              else
                unless @collection_keys_whitelist.include?(changed_key)
                  new_collection.send("#{changed_key}=", old_collection.send(changed_key))
                end
              end
            end
          end

          ForestLiana.apimap = collections
        rescue JSON::JSONError
          FOREST_LOGGER.error "File .forestadmin-schema.json does not appear to be valid json."
        end
      else
        FOREST_LOGGER.error "File .forestadmin-schema.json does not exist."\
          "Make sure to deploy this file in your production environment."
      end
    end

    def pretty_print_json(json, indentation = "")
      result = ""

      if json.kind_of?(Array)
        result << "["
        is_small = json.length < 3
        is_primary_value = false
        json.each_index do |index|
          item = json[index]
          is_primary_value = !item.kind_of?(Hash) && !item.kind_of?(Array)

          if index == 0 && is_primary_value && !is_small
            result << "\n" << indentation << "  "
          elsif index > 0 && is_primary_value && !is_small
            result << ",\n" << indentation << "  "
          elsif index > 0
            result << ", "
          end

          result << pretty_print_json(item, is_primary_value ? indentation + "  " : indentation);
        end

        if is_primary_value && !is_small
          result << "\n" << indentation
        end
        result << "]"
      elsif json.kind_of?(Hash)
        result << "{\n"

        is_first = true
        json = json.stringify_keys
        json.each do |key, value|
          unless is_first
            result << ",\n"
          end
          is_first = false
          result << indentation << '  "' << key << '": '
          result << pretty_print_json(value, indentation + "  ")
        end

        result << "\n" << indentation << "}"
      elsif json.nil?
        result << "null"
      elsif !!json == json
        result << (json ? "true" : "false")
      elsif json.is_a?(String) || json.is_a?(Symbol)
        result << '"' << json.to_s << '"'
      else
        result << json.to_s
      end

      result
    end

    def update_schema_file
      File.open(File.join(Rails.root, '.forestadmin-schema.json'), 'w') do |f|
        collections = ForestLiana.apimap.as_json

        # NOTICE: Remove unecessary keys
        collections = collections.map do |collection|
          collection[:fields] = collection[:fields].map do |field|
            unless field[:validations].nil?
              field[:validations] = field[:validations].map { |validation| validation.slice(*@validation_keys_whitelist) }
            end
            field.slice(*@field_keys_whitelist)
          end

          collection[:actions] = collection[:actions].map do |action|
            action.slice(*@action_keys_whitelist)
            action[:fields] = action[:fields].map { |field| field.slice(*@action_fields_keys_whitelist) }
          end

          collection['segments'] = collection['segments'].map do |segment|
            segment.slice(*@segment_keys_whitelist)
          end

          collection.slice(*@collection_keys_whitelist)
        end

        # NOTICE: Sort keys
        collections = collections.map do |collection|
          collection['fields'].sort { |field1, field2| [field1['field'], field1['type']] <=> [field2['field'], field2['type']] }
          collection['fields'] = collection['fields'].map do |field|
            unless field['validations'].nil?
              field['validations'] = field['validations'].map do |validation|
                validation.sort_by { |key, value| @validation_keys_whitelist.index key }.to_h
              end
            end
            field.sort_by { |key, value| @field_keys_whitelist.index key }.to_h
          end
          collection['actions'] = collection['actions'].map do |action|
            action.sort_by { |key, value| @action_keys_whitelist.index key }.to_h
          end
          collection.sort_by { |key, value| @collection_keys_whitelist.index key }.to_h
        end
        collections.sort { |collection1, collection2| collection1['name'] <=> collection2['name'] }

        f.puts pretty_print_json({
          collections: collections,
          meta: ForestLiana.meta
        })
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
      apimap = JSONAPI::Serializer.serialize(ForestLiana.apimap, {
        is_collection: true,
        include: ['actions', 'segments'],
        meta: ForestLiana.meta
      })

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
            reference: "#{model_name}.id",
            is_filterable: false
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
        icon: 'stripe',
        integration: 'stripe',
        is_virtual: true,
        is_read_only: true,
        is_searchable: false,
        pagination_type: 'cursor',
        fields: [
          { field: :id, type: 'String', is_filterable: false },
          { field: :amount_due, type: 'Number', is_filterable: false },
          { field: :attempt_count, type: 'Number', is_filterable: false },
          { field: :attempted, type: 'Boolean', is_filterable: false },
          { field: :closed, type: 'Boolean', is_filterable: false },
          { field: :currency, type: 'String', is_filterable: false },
          { field: :date, type: 'Date', is_filterable: false },
          { field: :forgiven, type: 'Boolean', is_filterable: false },
          { field: :period_start, type: 'Date', is_filterable: false },
          { field: :period_end, type: 'Date', is_filterable: false },
          { field: :subtotal, type: 'Number', is_filterable: false },
          { field: :total, type: 'Number', is_filterable: false },
          { field: :application_fee, type: 'Number', is_filterable: false },
          { field: :tax, type: 'Number', is_filterable: false },
          { field: :tax_percent, type: 'Number', is_filterable: false },
          {
            field: :customer,
            type: 'String',
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
