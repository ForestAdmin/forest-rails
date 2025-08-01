module ForestLiana
  class SchemaAdapter
    def initialize(model)
      @model = model
    end

    def perform
      add_columns
      add_associations

      collection.fields.sort_by!.with_index { |k, idx| [k[:field].to_s, idx] }

      # NOTICE: Add ActsAsTaggable fields
      if @model.try(:taggable?) && @model.respond_to?(:acts_as_taggable) &&
        @model.acts_as_taggable.respond_to?(:to_a)
        @model.acts_as_taggable.to_a.each do |key, value|
          field = collection.fields.find { |x| x[:field] == key.to_s }

          if field
            field[:type] = 'String'
            field[:reference] = nil
            field[:inverse_of] = nil

            collection.fields.delete_if do |f|
              ['taggings', 'base_tags', 'tag_taggings'].include?(f[:field])
            end
          end
        end
      end

      # NOTICE: Add Devise fields
      if @model.respond_to?(:devise_modules?)
        collection.actions << ForestLiana::Model::Action.new({
          id: "#{collection.name}.Change password",
          name: "Change password",
          fields: [{
            field: 'New password',
            type: 'String'
          }]
        })

        collection.fields.each do |field|
          if field[:field] == 'encrypted_password'
            field[:field] = 'password'
          end
        end
      end

      # NOTICE: Define an automatic segment for each STI child model.
      if is_sti_parent?
        if @model.descendants.empty?
          FOREST_LOGGER.warn "Looks like your Rails STI parent model named \"#{@model.name}\" " +
            "does not have any child model. If you want to deactivate the STI feature, add " +
            "\"self.inheritance_column = nil\" in the model."
        end

        column_type = @model.inheritance_column
        @model.descendants.each do |submodel_sti|
          type = submodel_sti.sti_name
          name = type.pluralize
          collection.segments << ForestLiana::Model::Segment.new({
            id: name,
            name: name,
            where: lambda { { column_type => type } }
          })
        end
      end

      collection
    end

    private

    def collection
      @collection ||= begin
        collection = ForestLiana.apimap.find do |object|
          object.name.to_s == ForestLiana.name_for(@model)
        end

        if collection.blank?
          collection = ForestLiana::Model::Collection.new({
            name: ForestLiana.name_for(@model),
              # TODO: Remove once lianas prior to 2.0.0 are not supported anymore.
            name_old: ForestLiana.name_old_for(@model),
            fields: []
          })

          ForestLiana.apimap << collection
        else
          # NOTICE: If the collection has Smart customisation (Fields, Action,
          #         ...), we force the is_virtual to false to handle the case
          #         when lib/forest_liana is loaded before the models.
          collection.is_virtual = false
        end

        collection
      end
    end

    def add_columns
      @model.columns.each do |column|
        unless is_sti_column_of_child_model?(column)
          field_schema = get_schema_for_column(column)
          collection.fields << field_schema unless field_schema.nil?
        end
      end

      # NOTICE: Add Intercom fields
      if ForestLiana.integrations.try(:[], :intercom)
        .try(:[], :mapping).try(:include?, @model.name)

        model_name = ForestLiana.name_for(@model)

        collection.fields << {
          field: :intercom_conversations,
          type: ['String'],
          relationship: 'HasMany',
          reference: "#{model_name}_intercom_conversations.id",
          column: nil,
          is_filterable: false,
          integration: 'intercom'
        }

        collection.fields << {
          field: :intercom_attributes,
          type: 'String',
          relationship: 'HasOne',
          reference: "#{model_name}_intercom_attributes.id",
          column: nil,
          is_filterable: false,
          integration: 'intercom'
        }
      end

      # NOTICE: Add Stripe fields
      stripe_mapping = ForestLiana.integrations.try(:[], :stripe)
                                               .try(:[], :mapping)

      if stripe_mapping
        if stripe_mapping
            .select { |mapping| mapping.split('.')[0] == @model.name }
            .size > 0

          model_name = ForestLiana.name_for(@model)

          collection.fields << {
            field: :stripe_payments,
            type: ['String'],
            relationship: 'HasMany',
            reference: "#{model_name}_stripe_payments.id",
            column: nil,
            is_filterable: false,
            integration: 'stripe'
          }

          collection.fields << {
            field: :stripe_invoices,
            type: ['String'],
            relationship: 'HasMany',
            reference: "#{model_name}_stripe_invoices.id",
            column: nil,
            is_filterable: false,
            integration: 'stripe'
          }

          collection.fields << {
            field: :stripe_cards,
            type: ['String'],
            relationship: 'HasMany',
            reference: "#{model_name}_stripe_cards.id",
            column: nil,
            is_filterable: false,
            integration: 'stripe'
          }

          collection.fields << {
            field: :stripe_subscriptions,
            type: ['String'],
            relationship: 'HasMany',
            reference: "#{model_name}_stripe_subscriptions.id",
            column: nil,
            is_filterable: false,
            integration: 'stripe'
          }

          collection.fields << {
            field: :stripe_bank_accounts,
            type: ['String'],
            relationship: 'HasMany',
            reference: "#{model_name}_stripe_bank_accounts.id",
            column: nil,
            is_filterable: false,
            integration: 'stripe'
          }
        end
      end

      # NOTICE: Add Mixpanel field
      mixpanel_mapping = ForestLiana.integrations
        .try(:[], :mixpanel)
        .try(:[], :mapping)

      if mixpanel_mapping && mixpanel_mapping
          .select { |mapping| mapping.split('.')[0] == @model.name }
          .size > 0

        model_name = ForestLiana.name_for(@model)

        collection.fields << {
          field: :mixpanel_last_events,
          type: ['String'],
          relationship: 'HasMany',
          reference: "#{model_name}_mixpanel_events.id",
          column: nil,
          is_filterable: false,
          integration: 'mixpanel',
        }
      end

      # NOTICE: Add Paperclip url attributes
      if @model.respond_to?(:attachment_definitions)
        @model.attachment_definitions.each do |key, value|
          collection.fields << { field: key, type: 'File' }

          collection.fields.delete_if do |f|
            ["#{key}_file_name", "#{key}_file_size", "#{key}_content_type",
             "#{key}_updated_at"].include?(f[:field])
          end
        end
      end

      # NOTICE: Add CarrierWave attributes
      if @model.respond_to?(:uploaders)
        @model.uploaders.each do |key, value|
          field = collection.fields.find { |x| x[:field] == key.to_s }
          field[:type] = 'File' if field
        end
      end
    end

    def add_associations
      SchemaUtils.associations(@model).each do |association|
        begin
          if SchemaUtils.polymorphic?(association) &&
            collection.fields << {
              field: association.name.to_s,
              type: get_type_for_association(association),
              relationship: get_relationship_type(association),
              reference: "#{association.name.to_s}.id",
              inverse_of: @model.name.demodulize.underscore,
              is_filterable: false,
              is_sortable: true,
              is_read_only: false,
              is_required: false,
              is_virtual: false,
              default_value: nil,
              integration: nil,
              relationships: nil,
              widget: nil,
              validations: [],
              polymorphic_referenced_models: get_polymorphic_types(association)
            }

            collection.fields = collection.fields.reject do |field|
              field[:field] == association.foreign_key || field[:field] == association.foreign_type
            end
          # NOTICE: Delete the association if the targeted model is excluded.
          elsif !SchemaUtils.model_included?(association.klass)
            field = collection.fields.find do |x|
              x[:field] == association.foreign_key
            end

            collection.fields.delete(field) if field
          # NOTICE: The foreign key exists, so it's a belongsTo relationship.
          elsif (field = column_association(collection, association)) &&
            [:has_one, :belongs_to].include?(association.macro)
              field[:reference] = get_reference_for(association)
              field[:field] = association.name
              field[:inverse_of] = inverse_of(association)
              field[:relationship] = get_relationship_type(association)

              ForestLiana::SchemaUtils.disable_filter_and_sort_if_cross_db!(
                field,
                association.name.to_s,
                ForestLiana.name_for(@model)
              )
              # NOTICE: Create the fields of hasOne, HasMany, … relationships.
          else
            collection.fields << get_schema_for_association(association)
          end
        rescue NameError
          FOREST_LOGGER.warn "The association \"#{association.name.to_s}\" " \
            "does not seem to exist for model \"#{@model.name}\"."
        rescue => exception
          FOREST_REPORTER.report exception
          FOREST_LOGGER.error "An error occured trying to add " \
            "\"#{association.name.to_s}\" association:\n#{exception}"
        end
      end
    end

    def inverse_of(association)
      association.inverse_of.try(:name).try(:to_s) ||
        automatic_inverse_of(association)
    end

    def get_polymorphic_types(relation)
      types = []
      ForestLiana.models.each do |model|
        unless model.reflect_on_all_associations.select { |association| association.options[:as] == relation.name.to_sym }.empty?
          types << model.name
        end
      end

      types
    end

    def automatic_inverse_of(association)
      name = association.active_record.name.demodulize.underscore

      inverse_association = association.klass.reflections.keys.find do |k|
        k.to_s == name || k.to_s == name.pluralize
      end

      inverse_association.try(:to_s)
    end

    def get_schema_for_column(column)
      column_type = get_type_for(column)
      return nil if column_type.nil?

      schema = {
        field: column.name,
        type: column_type,
        is_filterable: true,
        is_sortable: true,
        is_read_only: false,
        is_required: false,
        is_virtual: false,
        default_value: nil,
        integration: nil,
        reference: nil,
        inverse_of: nil,
        relationships: nil,
        widget: nil,
        validations: []
      }
      add_enum_values_if_is_enum(schema, column)
      add_enum_values_if_is_sti_model(schema, column)
      add_default_value(schema, column)
      add_validations(schema, column)
    end

    def get_schema_for_association(association)
      opts ={
        field: association.name.to_s,
        type: get_type_for_association(association),
        relationship: get_relationship_type(association),
        reference: "#{ForestLiana.name_for(association.klass)}.id",
        inverse_of: inverse_of(association),
        is_filterable: !is_many_association(association),
        is_sortable: true,
        is_read_only: false,
        is_required: false,
        is_virtual: false,
        default_value: nil,
        integration: nil,
        relationships: nil,
        widget: nil,
        validations: []
      }

      ForestLiana::SchemaUtils.disable_filter_and_sort_if_cross_db!(
        opts,
        association.name.to_s,
        ForestLiana.name_for(@model)
      )

      opts
    end

    def get_relationship_type(association)
      association.macro.to_s.camelize
    end

    def get_type_for(column)
      # NOTICE: Rails 3 do not have a defined_enums method
      if @model.respond_to?(:defined_enums) &&
          @model.defined_enums.has_key?(column.name)
        return 'Enum'
      end

      case column.type
      when :boolean
        type = 'Boolean'
      when :datetime
        type = 'Date'
      when :date
        type = 'Dateonly'
      when :integer, :float, :decimal
        type = 'Number'
      when :json, :jsonb, :hstore
        type = 'Json'
      when :string, :text, :citext
        type = 'String'
      when :time
        type = 'Time'
      when :uuid
        type = 'Uuid'
      end

      is_array = (column.respond_to?(:array) && column.array == true)
      is_array ? [type] : type
    end

    def add_enum_values_if_is_enum(column_schema, column)
      if column_schema[:type] == 'Enum'
        column_schema[:enums] = []
        @model.defined_enums[column.name].each do |name, value|
          column_schema[:enums] << name
        end
      end

      column_schema
    end

    def add_enum_values_if_is_sti_model(column_schema, column)
      if sti_column?(column)
        column_schema[:enums] = []
        column_schema[:type] = 'Enum'
        @model.descendants.each do |sti_model|
          column_schema[:enums] << sti_model.name
        end
      end

      column_schema
    end

    def sti_column?(column)
      @model.inheritance_column && column.name == @model.inheritance_column
    end

    def is_sti_parent?
      @model.try(:table_exists?) &&
        @model.inheritance_column &&
        @model.columns.any? { |column| sti_column?(column) } &&
        @model.name == @model.base_class.to_s
    end

    def is_sti_column_of_child_model?(column)
      sti_column?(column) && !is_sti_parent? && @model.descendants.empty?
    end

    def add_default_value(column_schema, column)
      # TODO: detect/introspect the attribute default value with Rails 5
      #       ex: attribute :email, :string, default: 'arnaud@forestadmin.com'
      column_schema[:default_value] = column.default if column.default
    end

    def add_validations(column_schema, column)
      # NOTICE: Do not consider validations if a before_validation Active Records
      #         Callback is detected.
      default_callback_excluded = [:normalize_changed_in_place_attributes]
      if @model._validation_callbacks
               .reject { |callback| default_callback_excluded.include?(callback.filter) }
               .map(&:kind).include?(:before)

        return column_schema
      end

      if @model._validators? && @model._validators[column.name.to_sym].size > 0
        @model._validators[column.name.to_sym].each do |validator|
          # NOTICE: Do not consider conditional validations
          next if validator.options[:if] || validator.options[:unless] || validator.options[:on]

          case validator
          when ActiveRecord::Validations::PresenceValidator
            column_schema[:validations] << {
              type: 'is present',
              message: validator.options[:message]
            }
            column_schema[:is_required] = true
          when ActiveModel::Validations::NumericalityValidator
            validator.options.each do |option, value|
              case option
              when :greater_than, :greater_than_or_equal_to
                column_schema[:validations] << {
                  type: 'is greater than',
                  value: value,
                  message: validator.options[:message]
                }
              when :less_than, :less_than_or_equal_to
                column_schema[:validations] << {
                  type: 'is less than',
                  value: value,
                  message: validator.options[:message]
                }
              end
            end
          when ActiveModel::Validations::LengthValidator
            if column_schema[:type] == 'String'
              validator.options.each do |option, value|
                case option
                when :minimum
                  column_schema[:validations] << {
                    type: 'is longer than',
                    value: value,
                    message: validator.options[:message]
                  }
                when :maximum
                  column_schema[:validations] << {
                    type: 'is shorter than',
                    value: value,
                    message: validator.options[:message]
                  }
                when :is
                  column_schema[:validations] << {
                    type: 'is longer than',
                    value: value,
                    message: validator.options[:message]
                  }
                  column_schema[:validations] << {
                    type: 'is shorter than',
                    value: value,
                    message: validator.options[:message]
                  }
                end
              end
            end
          when ActiveModel::Validations::FormatValidator
            validator.options.each do |option, value|
              case option
              when :with
                options = /\?([imx]){0,3}/.match(validator.options[:with].to_s)
                options = options && options[1] ? options[1] : ''
                regex = value.source

                # NOTICE: Transform a Ruby regex into a JS one
                regex = regex.sub('\\A' , '^').sub('\\Z' , '$').sub('\\z' , '$').gsub(/\n+|\s+/, '')

                column_schema[:validations] << {
                  type: 'is like',
                  value: "/#{regex}/#{options}",
                  message: validator.options[:message]
                }
              end
            end
          end
        end

        if column_schema[:validations].size == 0
          column_schema.delete(:validations)
        end
      end

      column_schema
    end

    def get_reference_for(association)
      if association.options[:polymorphic] == true
        '*.id'
      else
        "#{ForestLiana.name_for(association.klass)}.id"
      end
    end

    def column_association(collection, field)
      collection.fields.find {|x| x[:field] == field.foreign_key }
    end

    def is_many_association(association)
      association.macro == :has_many ||
        association.macro == :has_and_belongs_to_many
    end

    def get_type_for_association(association)
      if is_many_association(association)
        ['Number']
      else
        'Number'
      end
    end

    def deforeign_key(column_name)
      if column_name[-3..-1] == '_id'
        column_name[0..-4]
      else
        column_name
      end
    end

  end
end
