module ForestLiana
  class HasManyDissociator
    include ForestLiana::RecordFindable

    # A through association's plain unlink never touches the far collection at all — it destroys
    # (or, dependent: :nullify, just detaches) a row of the join collection instead. A plain
    # has_many only destroys the far record when its own dependent option says so.
    def self.destroys_on_unlink?(association)
      return association.options[:dependent] != :nullify if association.options[:through]

      association.macro == :has_many && %i[destroy delete_all].include?(association.options[:dependent])
    end

    # The collection a plain unlink actually writes to: the join collection for a through
    # association (see destroys_on_unlink?), the far collection otherwise.
    def self.destroy_target(association)
      association.options[:through] ? association.through_reflection.klass : association.klass
    end

    def initialize(resource, association, params, forest_user)
      @resource = resource
      @association = association
      @params = params
      @with_deletion = @params[:delete].to_s == 'true'
      @data = params['data']
      @forest_user = forest_user
    end

    def perform
      @record = find_record(@resource, @resource, @params[:id])
      associated_records = @record.send(@association.name)

      remove_association = !@with_deletion || @association.macro == :has_and_belongs_to_many
      if @data.is_a?(Array)
        record_ids = @data.map { |record| record[:id] }
      elsif @data.dig('attributes').present?
        record_ids = ForestLiana::ResourcesGetter.get_ids_from_request(@params, @forest_user)
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
          @resource.transaction do
            record_ids.each do |id|
              record = @association.klass.find(id)
              record.destroy!
            end
          end
        end
      end
    end
  end
end
