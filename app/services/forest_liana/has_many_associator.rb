module ForestLiana
  class HasManyAssociator
    include ForestLiana::RecordFindable

    def initialize(resource, association, params)
      @resource = resource
      @association = association
      @params = params
      @data = params['data']
    end

    def perform
      @record = find_record(@resource, @resource, @params[:id])
      associated_records = @record.send(@association.name)

      if @data.is_a?(Array)
        @data.each do |record_added|
          associated_records << @association.klass.find(record_added[:id])
        end
      end
    end
  end
end
