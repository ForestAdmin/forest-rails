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
      new_value = @association.klass.find(@data[:id]) if @data && @data[:id]
      @record.send("#{@association.name}=", new_value)

      @record.save()
    end
  end
end
