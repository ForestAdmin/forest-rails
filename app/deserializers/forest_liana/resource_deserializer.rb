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
            if data.is_a?(Hash)
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
  end
end
