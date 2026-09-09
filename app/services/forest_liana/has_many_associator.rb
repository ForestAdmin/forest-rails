module ForestLiana
  class HasManyAssociator
    include ForestLiana::RecordFindable

    # A through association's `<<` creates a row in the join collection, never touching the far
    # one — the far record found by id already exists and is left untouched. Falls back to the
    # far collection when the join model is hidden from the schema (ForestLiana.excluded_models),
    # same reasoning as HasManyDissociator.destroy_target.
    def self.authorize_target(association)
      join = association.options[:through] && association.through_reflection.klass
      join && SchemaUtils.model_included?(join) ? join : association.klass
    end

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
