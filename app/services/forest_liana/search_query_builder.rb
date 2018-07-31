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
      @records = search_param
      @records = filter_param
      @records = has_many_filter
      @records = belongs_to_filter

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
          @fields_searched << column.name if [:string, :text].include? column.type
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
          elsif !(column.respond_to?(:array) && column.array) &&
            (column.type == :string || column.type == :text)
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
          SchemaUtils.one_associations(@resource).map(&:name).each do
            |association|
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
                if !(column.respond_to?(:array) && column.array) &&
                  (column.type == :string || column.type == :text)
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
                  if !(column.respond_to?(:array) && column.array) &&
                    (column.type == :string || column.type == :text)
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

    def filter_param
      if @params[:filterType] && @params[:filter]
        conditions = []

        @params[:filter].each do |field, values|
          # ActsAsTaggable
          if acts_as_taggable?(field)
            tagged_records = @records.tagged_with(values.tr('*', ''))

            if @params[:filterType] == 'and'
              @records = tagged_records
            elsif @params[:filterType] == 'or'
              conditions << acts_as_taggable_query(tagged_records)
            end
          else
            next if association?(field)

            values.split(',').each do |value|
              operator, value = OperatorValueParser.parse(value)
              conditions << OperatorValueParser.get_condition(field, operator,
                value, @resource, @params[:timezone])
            end
          end
        end

        operator = " #{@params[:filterType]} ".upcase
        @records = @records.where(conditions.join(operator))
      end

      @records
    end

    def association?(field)
      field = field.split(':').first if field.include?(':')
      @resource.reflect_on_association(field.to_sym).present?
    end

    def has_many_association?(field)
      field = field.split(':').first if field.include?(':')
      association = @resource.reflect_on_association(field.to_sym)

      [:has_many, :has_and_belongs_to_many].include?(association.try(:macro))
    end

    def acts_as_taggable?(field)
      @resource.try(:taggable?) && @resource.respond_to?(:acts_as_taggable) &&
        @resource.acts_as_taggable.include?(field)
    end

    def has_many_filter
      if @params[:filter]
        @params[:filter].each do |field, values|
          next if !has_many_association?(field) || acts_as_taggable?(field)

          values.split(',').each do |value|
            if field.include?(':')
              @records = has_many_subfield_filter(field, value)
            else
              @records = has_many_field_filter(field, value)
            end
          end
        end
      end

      @records
    end

    def has_many_field_filter(field, value)
      association = @resource.reflect_on_association(field.to_sym)
      return if association.blank?

      operator, value = OperatorValueParser.parse(value)

      @records = @records
        .select("#{@resource.table_name}.*,
                COUNT(#{association.table_name}.id)
                #{association.table_name}_has_many_count")
        .joins(ArelHelpers.join_association(@resource, association.name,
          Arel::Nodes::OuterJoin))
        .group("#{@resource.table_name}.id")
        .having("COUNT(#{association.table_name}) #{operator} #{value}")
    end

    def has_many_subfield_filter(field, value)
      field, subfield = field.split(':')

      association = @resource.reflect_on_association(field.to_sym)
      return if association.blank?

      operator, value = OperatorValueParser.parse(value)

      @records = @records
        .select("#{@resource.table_name}.*,
                COUNT(#{association.table_name}.id)
                #{association.table_name}_has_many_count")
        .joins(ArelHelpers.join_association(@resource, association.name,
          Arel::Nodes::OuterJoin))
        .group("#{@resource.table_name}.id, #{association.table_name}.#{subfield}")
        .having("#{association.table_name}.#{subfield} #{operator} '#{value}'")
    end

    def belongs_to_association?(field)
      field = field.split(':').first if field.include?(':')
      association = @resource.reflect_on_association(field.to_sym)
      [:belongs_to, :has_one].include?(association.try(:macro))
    end

    def belongs_to_subfield_filter(field, value)
      field, subfield = field.split(':')

      association = @resource.reflect_on_association(field.to_sym)
      return if association.blank?

      operator, value = OperatorValueParser.parse(value)
      filter = OperatorValueParser
        .get_condition_end(subfield, operator, value, association.klass, @params[:timezone])

      association_name_pluralized = association.name.to_s.pluralize

      if association_name_pluralized == association.table_name
        # NOTICE: Default case. When the belongsTo association name and the referenced table name are identical.
        association_name_for_condition = association.table_name
      else
        # NOTICE: When the the belongsTo association name and the referenced table name are identical.
        #         Format with the ActiveRecord query generator style.
        association_name_for_condition = "#{association_name_pluralized}_#{@resource.table_name}"
      end

      @records.where("#{association_name_for_condition}.#{subfield} #{filter}")
    end

    def belongs_to_filter
      if @params[:filter]
        @params[:filter].each do |field, values|
          next unless belongs_to_association?(field)

          values.split(',').each do |value|
            @records = belongs_to_subfield_filter(field, value)
          end
        end
      end

      @records
    end
  end
end
