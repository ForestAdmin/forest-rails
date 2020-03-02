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

      if @data.is_a?(Array)
        record_ids = @data.map { |record| record[:id] }
      elsif @data.dig('attributes').present?
        record_ids = ForestLiana::ResourcesGetter.get_ids_from_request(@params)
      else
        record_ids = Array.new
      end

      if !record_ids.nil? && record_ids.any?
        if remove_association
          record_ids.each do |id|
            associated_records.delete(@association.klass.find(id))
          end
        end

        if @with_deletion
          record_ids = record_ids.select { |record_id| @association.klass.exists?(record_id) }
          @association.klass.destroy(record_ids)
        end
      end
    end
  end
end
