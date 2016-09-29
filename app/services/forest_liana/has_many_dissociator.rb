module ForestLiana
  class HasManyDissociator
    def initialize(resource, association, params)
      @resource = resource
      @association = association
      @params = params
      @data = params['data']
    end

    def perform
      @record = @resource.find(@params[:id])
      associated_records = @resource.find(@params[:id]).send(@association.name)

      if @data.is_a?(Array)
        @data.each do |record_deleted|
          associated_records.delete(
            @association.klass.find(record_deleted[:id]))
        end
      end
    end
  end
end
