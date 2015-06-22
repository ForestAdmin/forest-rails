module ForestRails
  class SchemaAdapter

    def initialize(model)
      @model = model
    end

    def perform
      @collection = Collection.new({ name: @model.name.tableize, fields: [] })
      add_columns
      add_associations

      @collection
    end

    private

    def add_columns
      @model.columns.each do |column|
        @collection.fields << get_schema_for_column(column)
      end
    end

    def add_associations
      @model.reflect_on_all_associations.each do |association|
        if schema = column_association(@collection, association)
          schema[:reference] = get_ref_for(association)
          schema[:field] = deforeign_key(schema[:field])
        else
          @collection.fields << get_schema_for_association(association)
        end
      end
    end

    def get_schema_for_column(column)
      { field: column.name, type: get_type_for(column) }
    end

    def get_schema_for_association(association)
      {
        field: association.name.to_s,
        type: get_type_for_association(association),
        reference: "#{association.name.to_s.tableize}.id"
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
        "#{association.class_name.to_s.tableize}.id"
      end
    end

    def column_association(collection, field)
      collection.fields.find {|x| x[:field] == field.foreign_key }
    end

    def get_type_for_association(association)
      if association.macro == :has_many
        '[Number]'
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
