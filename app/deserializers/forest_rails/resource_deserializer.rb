module ForestRails
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

          if data.is_a?(Hash) && column?(name.foreign_key)
            @attributes[name.foreign_key] = data[:id]
          end

        end
      end
    end

    def column?(attribute)
      @resource.columns.find {|x| x.name == attribute}.present?
    end

  end
end
