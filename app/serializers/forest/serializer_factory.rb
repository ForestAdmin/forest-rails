require 'jsonapi-serializers'

module Forest
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
        "Forest::#{active_record_class}Serializer".constantize;
      rescue
      end
    end

    def registered_serializer(active_record_class)
      @serializers[key(active_record_class)]
    end

    def generated_serializer(active_record_class)
      serializer = @serializers[key(active_record_class)] =
        Class.new {
          include JSONAPI::Serializer

          def self_link
            "/forest#{super}"
          end

          def format_name(attribute_name)
            attribute_name.to_s
          end

          def unformat_name(attribute_name)
            attribute_name.to_s.underscore
          end

          def relationship_self_link(attribute_name)
            nil
          end

          def relationship_related_link(attribute_name)
            relationship_records = object.send(attribute_name)
            return nil unless relationship_records.respond_to?(:each)

            {
              meta: { count: relationship_records.count }
            }
          end
        }

      attributes(active_record_class).each do |attr|
        serializer.attribute(attr)
      end

      associations(active_record_class).each do |association|
        # ignore polymorphic associations for now
        next if association.options[:polymorphic]
        serializer.send(serializer_association(association), association.name,
                        serializer: serializer_for(
                          association.class_name.constantize))
      end

      Forest.const_set("#{active_record_class.name}Serializer", serializer)
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

    def attributes(active_record_class)
      active_record_class.column_names.select do |column_name|
        !association?(active_record_class, column_name)
      end
    end

    def associations(active_record_class)
      active_record_class.reflect_on_all_associations
    end

    def association?(active_record_class, column_name)
      foreign_keys(active_record_class).include?(column_name)
    end

    def foreign_keys(active_record_class)
      associations(active_record_class).map do |association|
        association.foreign_key
      end
    end

  end
end
