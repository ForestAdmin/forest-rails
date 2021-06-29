module ForestLiana
  class ResourceCreator
    attr_accessor :record
    attr_accessor :errors

    def initialize(resource, params)
      @resource = resource
      @params = params
      @errors = nil
    end

    def perform
      begin
        if has_strong_parameter
          @record = @resource.create(resource_params)
        else
          @record = @resource.create(resource_params, without_protection: true)
        end
        set_has_many_relationships
      rescue ActiveRecord::StatementInvalid => exception
        # NOTICE: SQL request cannot be executed properly
        @errors = [{ detail: exception.cause.error }]
      rescue ForestLiana::Errors::SerializeAttributeBadFormat => exception
        @errors = [{ detail: exception.message }]
      rescue => exception
        @errors = [{ detail: exception.message }]
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, @params, true).perform
    end

    def set_has_many_relationships
      if @params['data']['relationships']
        @params['data']['relationships'].each do |name, relationship|
          data = relationship['data']
          association = @resource.reflect_on_association(name.to_sym)
          if [:has_many, :has_and_belongs_to_many].include?(
            association.try(:macro))
            if data.is_a?(Array)
              data.each do |x|
                existing_records = @record.send(name)
                if association.options[:polymorphic]
                  new_record = association.active_record.find(x[:id])
                else
                  new_record = association.klass.find(x[:id])
                end
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
      Rails::VERSION::MAJOR > 5 || @resource.instance_method(:update!).arity == 1
    end
  end
end
