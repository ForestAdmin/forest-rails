module ForestLiana
  class ResourceCreator
    attr_accessor :record

    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      if has_strong_parameter
        @record = @resource.create(resource_params)
      else
        @record = @resource.create(resource_params, without_protection: true)
      end
      set_has_many_relationships
    end

    def resource_params
      ResourceDeserializer.new(@resource, @params[:resource]).perform
    end

    def set_has_many_relationships
      if @params['data']['relationships']
        @params['data']['relationships'].each do |name, relationship|
          data = relationship['data']
          association = @resource.reflect_on_association(name)
          if [:has_many, :has_and_belongs_to_many].include?(
            association.try(:macro))
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

    def has_strong_parameter
      @resource.instance_method(:update_attributes!).arity == 1
    end
  end
end
