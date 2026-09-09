module ForestLiana
  class HasManyAssociator
    include ForestLiana::RecordFindable

    # A through association's `<<` creates a row in the join collection, never touching the far
    # one — the far record found by id already exists and is left untouched.
    def self.authorize_target(association)
      association.options[:through] ? association.through_reflection.klass : association.klass
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
