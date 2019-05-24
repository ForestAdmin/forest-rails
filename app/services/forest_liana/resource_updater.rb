module ForestLiana
  class ResourceUpdater
    attr_accessor :record
    attr_accessor :errors

    def initialize(resource, params)
      @resource = resource
      @params = params
      @errors = nil
    end

    def perform
      begin
        @record = @resource.find(@params[:id])

        if has_strong_parameter
          @record.update_attributes(resource_params)
        elsif Rails::VERSION::MAJOR >= 5
          @record.update_attributes(resource_params.to_unsafe_hash)
        elsif Rails::VERSION::MAJOR == 4
          @record.update_attributes(resource_params.to_hash)
        else
          @record.update_attributes(resource_params, without_protection: true)
        end
      rescue ActiveRecord::StatementInvalid => exception
        # NOTICE: SQL request cannot be executed properly
        @errors = [{ detail: exception.cause.error }]
      rescue ForestLiana::Errors::SerializeAttributeBadFormat => exception
        @errors = [{ detail: exception.message }]
      rescue => exception
        @errors = [{ detail: exception.message }]
      end
    end

    def resource_params
      ResourceDeserializer.new(@resource, @params, false).perform
    end

    def has_strong_parameter
      @resource.instance_method(:update_attributes!).arity == 1
    end
  end
end
