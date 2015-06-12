module ForestRails
  class SerializerFactory
    def initialize
      @serializers = {}
    end

    def serializer_for(active_record_class)
      overriden_serializer(active_record_class) ||
        registered_serializer(active_record_class) ||
        generated_serializer(active_record_class)
    end

    private

    def overriden_serializer(active_record_class)
      begin
        "ForestRails::#{active_record_class}Serializer".constantize;
      rescue
      end
    end

    def registered_serializer(active_record_class)
      @serializers[key(active_record_class)]
    end

    def generated_serializer(active_record_class)
      associations = active_record_class.reflect_on_all_associations
      column_names = active_record_class.column_names
      key = key(active_record_class)

      serializer = @serializers[key] = Class.new(ActiveModel::Serializer)
      serializer.attributes(*column_names)
      associations.each do |association|
        serializer.send(
          serializer_association(association), association.name,
          serializer: serializer_for(association.active_record))
      end
      serializer
    end

    def key(active_record_class)
      active_record_class.to_s.tableize.to_sym
    end

    def serializer_association(association)
      case association.macro
      when :has_one, :belongs_to
        :has_one
      when :has_many, :has_and_belongs_to_many
        :has_many
      end
    end

  end
end
