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
        if (SchemaUtils.polymorphic?(@association))
          if @data.nil?
            new_value = nil
          else
            association_klass = SchemaUtils.polymorphic_models(@association).select { |a| a.name.downcase == @data[:type] }.first
            new_value = association_klass.find(@data[:id]) if @data && @data[:id]
          end
        else
          new_value = @association.klass.find(@data[:id]) if @data && @data[:id]
        end
        @record.send("#{@association.name}=", new_value)

        @record.save
      rescue ActiveRecord::SerializationTypeMismatch => exception
        @errors = [{ detail: exception.message }]
      rescue => exception
        @errors = [{ detail: exception.message }]
      end
    end
  end
end
