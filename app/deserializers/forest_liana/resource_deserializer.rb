require_relative '../../../lib/forest_liana/base64_string_io'

module ForestLiana
  class ResourceDeserializer

    def initialize(resource, params, with_relationships)
      @params = params.permit! if params.respond_to?(:permit!)
      @resource = resource
      @with_relationships = with_relationships
    end

    def perform
      @attributes = extract_attributes
      extract_attributes_serialize
      extract_relationships if @with_relationships
      extract_paperclip
      extract_carrierwave
      extract_acts_as_taggable
      extract_devise

      @attributes
    end

    def extract_attributes
      if @params[:data][:attributes]
        @params['data']['attributes'].select { |attribute| column?(attribute) }
      else
        ActionController::Parameters.new()
      end
    end

    def extract_attributes_serialize
      attributes_serialized.each do |attribute, serializer|
        value = @params[:data][:attributes][attribute]
        @attributes[attribute] = JSON::parse(value)
      end
    end

    def extract_relationships
      if @params['data']['relationships']
        @params['data']['relationships'].each do |name, relationship|
          data = relationship['data']
          # Rails 3 requires a :sym argument for the reflect_on_association
          # call.
          association = @resource.reflect_on_association(name.try(:to_sym))

          if [:has_one, :belongs_to].include?(association.try(:macro))
            # TODO: refactor like this?
            #if data.blank?
              #@attributes[name] = nil
            #else
              #@attributes[name] = association.klass.find(data[:id])
            #end

            # ActionController::Parameters do not inherit from Hash anymore
            # since Rails 5.
            if (data.is_a?(Hash) || data.is_a?(ActionController::Parameters)) && data[:id]
              @attributes[name] = association.klass.find(data[:id])
            elsif data.blank?
              @attributes[name] = nil
            end
          end
        end

        # Strong parameter permit all new relationships attributes.
        @attributes = @attributes.permit! if @attributes.respond_to?(:permit!)
      end
    end

    def extract_paperclip
      return if @params['data']['attributes'].blank?
      return unless @resource.respond_to?(:attachment_definitions)

      paperclip_attr = @params['data']['attributes']
        .select do |attr|
          !column?(attr) &&
            paperclip_handler?(@params['data']['attributes'][attr])
        end

      @attributes.merge!(paperclip_attr) if paperclip_attr
    end

    def extract_carrierwave
      return if @params['data']['attributes'].blank?
      return unless @resource.respond_to?(:uploaders)

      @params['data']['attributes'].each do |key, value|
        if value && carrierwave_attribute?(key)
          @attributes[key] = ForestLiana::Base64StringIO.new(value)
        end
      end
    end

    def extract_acts_as_taggable
      return if @params['data']['attributes'].blank?
      return unless has_acts_as_taggable?

      @params['data']['attributes'].each do |key, value|
        if acts_as_taggable_attribute?(key)
          @attributes["#{key.singularize}_list"] = value
          @attributes.delete(key)
        end
      end
    end

    def extract_devise
      return if @params['data']['attributes'].blank?
      return unless has_devise?

      @attributes['password'] = @params['data']['attributes']['password']
    end

    def paperclip_handler?(attr)
      begin
        Paperclip.io_adapters.handler_for(attr)
        true
      rescue Paperclip::AdapterRegistry::NoHandlerError
        false
      end
    end

    def column?(attribute)
      @resource.columns.find { |column| column.name == attribute }.present?
    end

    def attributes_serialized
      if Rails::VERSION::MAJOR >= 5
        @attributes.select do |attribute|
          @resource.type_for_attribute(attribute).class ==
            ::ActiveRecord::Type::Serialized
        end
      else
        @resource.serialized_attributes
      end
    end

    def carrierwave_attribute?(attr)
      @resource.uploaders.include?(attr.try(:to_sym))
    end

    def acts_as_taggable_attribute?(attr)
      @resource.acts_as_taggable.to_a.include?(attr)
    end

    def has_acts_as_taggable?
      @resource.respond_to?(:acts_as_taggable) &&
        @resource.acts_as_taggable.respond_to?(:to_a)
    end

    def has_devise?
      @resource.respond_to?(:devise_modules?)
    end
  end
end
