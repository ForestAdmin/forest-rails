module ForestLiana
  class ResourceDeserializer

    def initialize(resource, record, params)
      @params = params
      @resource = resource
      @record = record
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
          association = @resource.reflect_on_association(name)

          case association.try(:macro)
          when :has_one, :belongs_to
            if data.is_a?(Hash)
              @attributes[name] = association.klass.find(data[:id])
            elsif data.blank?
              @attributes[name] = nil
            end
          when :has_many, :has_and_belongs_to_many
            if data.is_a?(Array)
              data.each do |x|
                existing_records = @record.send(name)
                new_record = association.klass.find(x[:id])
                if !existing_records.include?(new_record)
                  existing_records << new_record
                end
              end
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
