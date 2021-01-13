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
          @record.update(resource_params)
        else
          @record.update(resource_params, without_protection: true)
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
      Rails::VERSION::MAJOR > 5 || @resource.instance_method(:update_attributes!).arity == 1
    end
  end
end
