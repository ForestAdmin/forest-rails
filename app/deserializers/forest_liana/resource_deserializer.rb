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
      @params['data']['attributes'].select {|attr| column?(attr)}
    end

    def extract_relationships
      if @params['data']['relationships']
        @params['data']['relationships'].each do |name, relationship|
          data = relationship['data']

          if column?(name.foreign_key) # belongs_to
            if data.is_a?(Hash)
              @attributes[name.foreign_key] = data[:id]
            elsif !data
              @attributes[name.foreign_key] = nil
            end
          elsif data # has_many
            @attributes[name] = data.map do |x|
              associated_record(x[:type], x[:id])
            end
          end
        end
      end
    end

    def extract_paperclip
      return unless @resource.try(:attachment_definitions)

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

    def associated_record(type, id)
      resource = SchemaUtils.find_model_from_table_name(type.underscore)
      resource.find(id)
    end

  end
end
