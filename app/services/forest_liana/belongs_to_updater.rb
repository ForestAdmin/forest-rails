module ForestLiana
  class BelongsToUpdater
    attr_accessor :errors

    def initialize(resource, association, params)
      @resource = resource
      @association = association
      @params = params
      @data = params['data']
      @errors = nil
    end

    def perform
      begin
        @record = @resource.find(@params[:id])
        new_value = @association.klass.find(@data[:id]) if @data && @data[:id]
        @record.send("#{@association.name}=", new_value)

        @record.save
      rescue ActiveRecord::SerializationTypeMismatch => exception
        ForestLiana.error_handler.call(exception)
        @errors = [{ detail: exception.message }]
      rescue => exception
        ForestLiana.error_handler.call(exception)
        @errors = [{ detail: exception.message }]
      end
    end
  end
end
