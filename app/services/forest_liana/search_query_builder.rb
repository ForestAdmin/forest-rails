module ForestLiana
  class SearchQueryBuilder
    REGEX_UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    attr_reader :fields_searched

    def initialize(params, includes, collection)
      @params = params
      @includes = includes
      @collection = collection
      @fields_searched = []
      @search = @params[:search]
    end

    def perform(resource)
      @resource = @records = resource
      @tables_associated_to_relations_name =
        ForestLiana::QueryHelper.get_tables_associated_to_relations_name(@resource)
      @records = search_param

      if @params[:filters]
        @records = FilterParser.new(@params[:filters], @resource, @params[:timezone]).apply_filters
      end

      if @search
        ForestLiana.schema_for_resource(@resource).fields.each do |field|
          if field.try(:[], :search)
            begin
              @records = field[:search].call(@records, @search)
            rescue => exception
              FOREST_LOGGER.error "Cannot search properly on Smart Field:\n" \
                "#{exception}"
            end
          end
        end
      end

      @records
    end

    def format_column_name(table_name, column_name)
      ForestLiana::AdapterHelper.format_column_name(table_name, column_name)
    end

    def acts_as_taggable_query(tagged_records)
      ids = tagged_records
        .map {|t| t[@resource.primary_key]}
        .join(',')

      if ids.present?
        return "#{@resource.primary_key} IN (#{ids})"
      end
    end

    def search_param
      if @search
        conditions = []

        @resource.columns.each_with_index do |column, index|
          @fields_searched << column.name if text_type? column.type
          column_name = format_column_name(@resource.table_name, column.name)
          if (@collection.search_fields && !@collection.search_fields.include?(column.name))
            conditions
          elsif column.name == 'id'
            if column.type == :integer
              value = @search.to_i
              conditions << "#{@resource.table_name}.id = #{value}" if value > 0
            elsif REGEX_UUID.match(@search)
              conditions << "#{@resource.table_name}.id = :search_value_for_uuid"
            end
          # NOTICE: Rails 3 do not have a defined_enums method
          elsif @resource.respond_to?(:defined_enums) &&
            @resource.defined_enums.has_key?(column.name) &&
            !@resource.defined_enums[column.name][@search.downcase].nil?
            conditions << "#{column_name} =
              #{@resource.defined_enums[column.name][@search.downcase]}"
          elsif !(column.respond_to?(:array) && column.array) && text_type?(column.type)
            conditions << "LOWER(#{column_name}) LIKE :search_value_for_string"
          end
        end

        # ActsAsTaggable
        if @resource.try(:taggable?) && @resource.respond_to?(:acts_as_taggable)
          @resource.acts_as_taggable.each do |field|
            tagged_records = @records.tagged_with(@search.downcase)
            condition = acts_as_taggable_query(tagged_records)
            conditions << condition if condition
          end
        end

        if (@params['searchExtended'].to_i == 1)
          ForestLiana::QueryHelper.get_one_association_names_symbol(@resource).each do |association|
            if @collection.search_fields
              association_search = @collection.search_fields.map do |field|
                if field.include?('.') && field.split('.')[0] == association.to_s
                  field.split('.')[1]
                end
              end
              association_search = association_search.compact
            end
            if @includes.include? association.to_sym
              resource = @resource.reflect_on_association(association.to_sym)
              resource.klass.columns.each do |column|
                if !(column.respond_to?(:array) && column.array) && text_type?(column.type)
                  if @collection.search_fields.nil? || (association_search &&
                    association_search.include?(column.name))
                    conditions << association_search_condition(resource.table_name,
                      column.name)
                  end
                end
              end
            end
          end

          if @collection.search_fields
            SchemaUtils.many_associations(@resource).map(&:name).each do
              |association|
              association_search = @collection.search_fields.map do |field|
                if field.include?('.') && field.split('.')[0] == association.to_s
                  field.split('.')[1]
                end
              end
              association_search = association_search.compact
              unless association_search.empty?
                resource = @resource.reflect_on_association(association.to_sym)
                resource.klass.columns.each do |column|
                  if !(column.respond_to?(:array) && column.array) && text_type?(column.type)
                    if association_search.include?(column.name)
                      conditions << association_search_condition(resource.table_name,
                        column.name)
                    end
                  end
                end
              end
            end
          end
        end

        @records = @resource.where(
          conditions.join(' OR '),
          search_value_for_string: "%#{@search.downcase}%",
          search_value_for_uuid: @search.to_s
        )
      end

      @records
    end

    def association_search_condition table_name, column_name
      column_name = format_column_name(table_name, column_name)
      "LOWER(#{column_name}) LIKE :search_value_for_string"
    end

    def acts_as_taggable?(field)
      @resource.try(:taggable?) && @resource.respond_to?(:acts_as_taggable) &&
        @resource.acts_as_taggable.include?(field)
    end

    private

    def text_type?(type_sym)
      [:string, :text, :citext].include? type_sym
    end
  end
end
