module ForestLiana
  class HasManyDissociator
    def initialize(resource, association, params)
      @resource = resource
      @association = association
      @params = params
      @with_deletion = @params[:delete].to_s == 'true'
      @data = params['data']
    end

    def perform
      @record = @resource.find(@params[:id])
      associated_records = @resource.find(@params[:id]).send(@association.name)

      remove_association = !@with_deletion || @association.macro == :has_and_belongs_to_many

      if remove_association
        if @data.is_a?(Array)
          @data.each do |record_deleted|
            associated_records.delete(@association.klass.find(record_deleted[:id]))
          end
        end
      end

      if @with_deletion
        if @data.is_a?(Array)
          record_ids = @data.map { |record| record[:id] }
          @association.klass.destroy(record_ids)
        end
      end
    end
  end
end
