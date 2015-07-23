module Forest
  class ResourceDeserializer

    def initialize(resource, params)
      @params = params
      @resource = resource
    end

    def perform
      @attributes = extract_attributes
      extract_relationships

      @attributes
    end

    def extract_attributes
      @params.require(:data).require(:attributes).permit!
    end

    def extract_relationships
      if @params[:data][:relationships]
        @params[:data][:relationships].each do |name, relationship|
          data = relationship[:data]

          if column?(name.foreign_key)
            if data.is_a?(Hash)
              @attributes[name.foreign_key] = data[:id]
            elsif !data
              @attributes[name.foreign_key] = nil
            end
          end
        end
      end
    end

    def column?(attribute)
      @resource.columns.find {|x| x.name == attribute}.present?
    end

  end
end
