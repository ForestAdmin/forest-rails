module ForestLiana
  class SchemaAdapter
    def initialize(model)
      @model = model
    end

    def perform
      add_columns
      add_associations

      # NOTICE: Add ActsAsTaggable fields
      if @model.respond_to?(:acts_as_taggable) &&
        @model.acts_as_taggable.respond_to?(:to_a) &&
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
        collection.fields << {
          field: 'password',
          type: 'String'
        }

        collection.fields.delete_if do |f|
          ['encrypted_password'].include?(f[:field])
        end
      end

      collection
    end

    private

    def collection
      @collection ||= begin
        collection = ForestLiana.apimap.find do |x|
          x.name.to_s == @model.table_name
        end

        if collection.blank?
          collection = ForestLiana::Model::Collection.new({
            name: @model.table_name,
            fields: []
          })

          ForestLiana.apimap << collection
        end

        collection
      end
    end

    def add_columns
      @model.columns.each do |column|
        collection.fields << get_schema_for_column(column)
      end

      # NOTICE: Add Intercom fields
      if ForestLiana.integrations.try(:[], :intercom)
        .try(:[], :mapping).try(:include?, @model.name)

        model_name = @model.table_name

        collection.fields << {
          field: :intercom_conversations,
          type: ['String'],
          reference: "#{model_name}_intercom_conversations.id",
          column: nil,
          is_searchable: false,
          integration: 'intercom'
        }

        @collection.fields << {
          field: :intercom_attributes,
          type: 'String',
          reference: "#{model_name}_intercom_attributes.id",
          column: nil,
          is_searchable: false,
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

          model_name = @model.table_name

          collection.fields << {
            field: :stripe_payments,
            type: ['String'],
            reference: "#{model_name}_stripe_payments.id",
            column: nil,
            is_searchable: false,
            integration: 'stripe'
          }

          collection.fields << {
            field: :stripe_invoices,
            type: ['String'],
            reference: "#{model_name}_stripe_invoices.id",
            column: nil,
            is_searchable: false,
            integration: 'stripe'
          }

          collection.fields << {
            field: :stripe_cards,
            type: ['String'],
            reference: "#{model_name}_stripe_cards.id",
            column: nil,
            is_searchable: false,
            integration: 'stripe'
          }

          collection.fields << {
            field: :stripe_subscriptions,
            type: ['String'],
            reference: "#{model_name}_stripe_subscriptions.id",
            column: nil,
            is_searchable: false,
            integration: 'stripe'
          }

          collection.fields << {
            field: :stripe_bank_accounts,
            type: ['String'],
            reference: "#{model_name}_stripe_bank_accounts.id",
            column: nil,
            is_searchable: false,
            integration: 'stripe'
          }
        end
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
          # NOTICE: Delete the association if the targeted model is excluded.
          if !SchemaUtils.model_included?(association.klass)
            field = collection.fields.find do |x|
              x[:field] == association.foreign_key
            end

            collection.fields.delete(field) if field
          # NOTICE: The foreign key exists, so it's a belongsTo relationship.
          elsif field = column_association(collection, association)
            field[:reference] = get_ref_for(association)
            field[:field] = deforeign_key(field[:field])
            field[:inverseOf] = inverse_of(association)
          # NOTICE: Create the fields of hasOne, HasMany, … relationships.
          else
            collection.fields << get_schema_for_association(association)
          end
        rescue NameError
          FOREST_LOGGER.warn "The association \"#{association.name.to_s}\" " \
            "does not seem to exist for model \"#{@model.name}\"."
        rescue => exception
          FOREST_LOGGER.error "An error occured trying to add " \
            "\"#{association.name.to_s}\" association:\n#{exception}"
        end
      end
    end

    def inverse_of(association)
      association.inverse_of.try(:name).try(:to_s) ||
        automatic_inverse_of(association)
    end

    def automatic_inverse_of(association)
      name = association.active_record.name.demodulize.underscore

      inverse_association = association.klass.reflections.keys.find do |k|
        k.to_s == name || k.to_s == name.pluralize
      end

      inverse_association.try(:to_s)
    end

    def get_schema_for_column(column)
      schema = { field: column.name, type: get_type_for(column) }
      add_enum_values_if_is_enum(schema, column)
    end

    def get_schema_for_association(association)
      {
        field: association.name.to_s,
        type: get_type_for_association(association),
        reference: "#{association.klass.table_name}.id",
        inverseOf: inverse_of(association)
      }
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
      when :datetime, :date
        type = 'Date'
      when :integer, :float, :decimal
        type = 'Number'
      when :json, :jsonb
        type = 'Json'
      when :string, :text, :citext, :uuid
        type = 'String'
      when :time
        type = 'Time'
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

    def get_ref_for(association)
      if association.options[:polymorphic] == true
        '*.id'
      else
        "#{association.klass.table_name.underscore}.id"
      end
    end

    def column_association(collection, field)
      collection.fields.find {|x| x[:field] == field.foreign_key }
    end

    def get_type_for_association(association)
      if association.macro == :has_many ||
        association.macro == :has_and_belongs_to_many
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
