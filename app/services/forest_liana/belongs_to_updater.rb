module ForestLiana
  class BelongsToUpdater
    def initialize(resource, association, params)
      @resource = resource
      @association = association
      @params = params
      @data = params['data']
    end

    def perform
      @record = @resource.find(@params[:id])
      if @data && @data[:id]
        new_value = @association.klass.find(@data[:id]) if @data && @data[:id]
        @record.send("#{@association.name}=", new_value)
      else
        @record.send("#{@association.foreign_key}=", nil)
        @record.save()
      end
    end
  end
end
