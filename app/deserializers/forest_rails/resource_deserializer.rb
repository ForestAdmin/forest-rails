module ForestRails
  class ResourceDeserializer

    def initialize(params)
      @params = params
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

          if data.is_a?(Hash)
            @attributes[data[:type].singularize.foreign_key] = data[:id]
          end

        end
      end

    end

  end
end
