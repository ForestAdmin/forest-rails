module ForestLiana
  class SchemaAdapter
    def initialize(model)
      @model = model
    end

    def perform
      @collection = ForestLiana::Model::Collection.new({
        name: @model.table_name,
        fields: []
      })

      add_columns
      add_associations

      # ActsAsTaggable attribute
      if @model.respond_to?(:acts_as_taggable) && @model.acts_as_taggable.try(:to_a)
        @model.acts_as_taggable.to_a.each do |key, value|
          field = @collection.fields.find {|x| x[:field] == key.to_s}

          if field
            field[:type] = 'String'
            field[:reference] = nil
            field[:inverse_of] = nil

            @collection.fields.delete_if do |f|
              ['taggings', 'base_tags', 'tag_taggings'].include?(f[:field])
            end
          end
        end
      end

      @collection
    end

    private

    def add_columns
      @model.columns.each do |column|
        @collection.fields << get_schema_for_column(column)
      end

      # Intercom
      if ForestLiana.integrations.try(:[], :intercom)
        .try(:[], :user_collection) == @model.name
        @collection.fields << {
          field: :intercom_conversations,
          type: ['String'],
          reference: 'intercom_conversations.id',
          column: nil,
          is_searchable: false,
          integration: 'intercom'
        }

        @collection.fields << {
          field: :intercom_attributes,
          type: 'String',
          reference: 'intercom_attributes.id',
          column: nil,
          is_searchable: false,
          integration: 'intercom'
        }
      end

      # Stripe
      if ForestLiana.integrations.try(:[], :stripe)
        .try(:[], :user_collection) == @model.name
        @collection.fields << {
          field: :stripe_payments,
          type: ['String'],
          reference: 'stripe_payments.id',
          column: nil,
          is_searchable: false,
          integration: 'stripe'
        }

        @collection.fields << {
          field: :stripe_invoices,
          type: ['String'],
          reference: 'stripe_invoices.id',
          column: nil,
          is_searchable: false,
          integration: 'stripe'
        }

        @collection.fields << {
          field: :stripe_cards,
          type: ['String'],
          reference: 'stripe_cards.id',
          column: nil,
          is_searchable: false,
          integration: 'stripe'
        }
      end

      # Paperclip url attribute
      if @model.respond_to?(:attachment_definitions)
        @model.attachment_definitions.each do |key, value|
          @collection.fields << { field: key, type: 'File' }
        end

        @collection.fields.delete_if do |f|
          ['picture_file_name', 'picture_file_size', 'picture_content_type',
           'picture_updated_at'].include?(f[:field])
        end
      end

      # CarrierWave attribute
      if @model.respond_to?(:uploaders)
        @model.uploaders.each do |key, value|
          field = @collection.fields.find {|x| x[:field] == key.to_s}
          field[:type] = 'File' if field
        end
      end
    end

    def add_associations
      SchemaUtils.associations(@model).each do |association|
        begin
          if schema = column_association(@collection, association)
            schema[:reference] = get_ref_for(association)
            schema[:field] = deforeign_key(schema[:field])
            schema[:inverseOf] = inverse_of(association)
          else
            @collection.fields << get_schema_for_association(association)
          end
        rescue => error
          puts error.inspect
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
      { field: column.name, type: get_type_for(column) }
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
      case column.type
      when :integer
        'Number'
      when :float
        'Number'
      when :decimal
        'Number'
      when :datetime
        'Date'
      when :date
        'Date'
      when :string
        'String'
      when :text
        'String'
      when :boolean
        'Boolean'
      end
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
