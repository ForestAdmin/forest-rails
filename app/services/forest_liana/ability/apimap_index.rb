module ForestLiana
  module Ability
    # The apimap lookups a field-read check repeats once per requested field, made once per check
    # instead: a wide collection on a large schema otherwise rescans every collection, and every
    # field of the root one, for each field a page displays.
    class ApimapIndex
      def initialize(apimap)
        @collections_by_name = apimap.each_with_object({}) { |collection, index| index[collection.name.to_s] ||= collection }
        @collections_by_model = {}
        @fields_by_name = {}
        @smart_belongs_to_by_name = {}
      end

      def collection_for(model)
        @collections_by_model.fetch(model) do
          @collections_by_model[model] = @collections_by_name[ForestLiana.name_for(model)]
        end
      end

      def exposed?(collection_name)
        @collections_by_name.key?(collection_name)
      end

      def fields_named(model, field_name)
        @fields_by_name[model] ||= first_by_name(collection_for(model)&.fields.to_a, all: true)
        @fields_by_name[model][field_name] || []
      end

      def smart_belongs_to(model, field_name)
        @smart_belongs_to_by_name[model] ||= first_by_name(collection_for(model)&.fields_smart_belongs_to.to_a)
        @smart_belongs_to_by_name[model][field_name]
      end

      private

      def first_by_name(fields, all: false)
        fields.each_with_object({}) do |field, index|
          name = field[:field].to_s
          all ? (index[name] ||= []) << field : index[name] ||= field
        end
      end
    end
  end
end
