require_relative '../../../lib/forest_liana/base64_string_io'

module ForestLiana
  class ResourceDeserializer

    def initialize(resource, params)
      @params = params
      @resource = resource
    end

    def perform
      @attributes = extract_attributes
      extract_relationships
      extract_paperclip
      extract_carrierwave
      extract_acts_as_taggable

      @attributes.permit! if @attributes.respond_to?(:permit!)
      @attributes
    end

    def extract_attributes
      if @params[:data][:attributes]
        @params['data']['attributes'].select {|attr| column?(attr)}
      else
        ActionController::Parameters.new()
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
            if data.is_a?(Hash) && data[:id]
              @attributes[name] = association.klass.find(data[:id])
            elsif data.blank?
              @attributes[name] = nil
            end
          end
        end
      end
    end

    def extract_paperclip
      return unless @resource.respond_to?(:attachment_definitions)

      paperclip_attr = @params['data']['attributes']
        .select do |attr|
          !column?(attr) &&
            paperclip_handler?(@params['data']['attributes'][attr])
        end

      @attributes.merge!(paperclip_attr) if paperclip_attr
    end

    def extract_carrierwave
      return unless @resource.respond_to?(:uploaders)

      @params['data']['attributes'].each do |key, value|
        if value && carrierwave_attribute?(key)
          @attributes[key] = ForestLiana::Base64StringIO.new(value)
        end
      end
    end

    def extract_acts_as_taggable
      return unless has_acts_as_taggable?

      @params['data']['attributes'].each do |key, value|
        if acts_as_taggable_attribute?(key)
          @attributes["#{key.singularize}_list"] = value
          @attributes.delete(key)
        end
      end

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
      @resource.columns.find {|x| x.name == attribute}.present?
    end

    def carrierwave_attribute?(attr)
      @resource.uploaders.include?(attr.try(:to_sym))
    end

    def acts_as_taggable_attribute?(attr)
      @resource.acts_as_taggable.to_a.include?(attr)
    end

    def has_acts_as_taggable?
      @resource.respond_to?(:acts_as_taggable) &&
        @resource.acts_as_taggable.try(:to_a)
    end
  end
end
