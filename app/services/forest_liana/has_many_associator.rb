module ForestLiana
  class HasManyAssociator
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
        @data.each do |record_added|
          if @association.options[:polymorphic]
            associated_records << @association.active_record.find(record_added[:id])
          else
            associated_records << @association.klass.find(record_added[:id])
          end
        end
      end
    end
  end
end
