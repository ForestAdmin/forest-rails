module ForestLiana
  class SearchQueryBuilder
    REGEX_UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

    def initialize(resource, params, includes)
      @resource = @records = resource
      @params = params
      @includes = includes
    end

    def perform
      @records = search_param
      @records = filter_param
      @records = has_many_filter
      @records = belongs_to_filter

      if @params[:search]
        ForestLiana.schema_for_resource(@resource).fields.each do |field|
          if field.try(:[], :search)
            begin
              @records = field[:search].call(@records, @params[:search])
            rescue => exception
              FOREST_LOGGER.error "Cannot search properly on Smart Field :\n" \
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
      if @params[:search]
        conditions = []

        @resource.columns.each_with_index do |column, index|
          column_name = format_column_name(@resource.table_name, column.name)
          if column.name == 'id'
            if column.type == :integer
              conditions << "#{@resource.table_name}.id =
                #{@params[:search].to_i}"
            elsif REGEX_UUID.match(@params[:search])
              conditions << "#{@resource.table_name}.id =
                '#{@params[:search]}'"
            end
          # NOTICE: Rails 3 do not have a defined_enums method
          elsif @resource.respond_to?(:defined_enums) &&
            @resource.defined_enums.has_key?(column.name) &&
            !@resource.defined_enums[column.name][@params[:search].downcase].nil?
            conditions << "#{column_name} =
              #{@resource.defined_enums[column.name][@params[:search].downcase]}"
          elsif !(column.respond_to?(:array) && column.array) &&
            (column.type == :string || column.type == :text)
            conditions << "LOWER(#{column_name}) LIKE '%#{@params[:search].downcase}%'"
          end
        end

        # ActsAsTaggable
        if @resource.respond_to?(:acts_as_taggable)
          @resource.acts_as_taggable.each do |field|
            tagged_records = @records.tagged_with(@params[:search].downcase)
            condition = acts_as_taggable_query(tagged_records)
            conditions << condition if condition
          end
        end

        SchemaUtils.one_associations(@resource).map(&:name).each do |association|
          if @includes.include? association.to_sym
            resource = @resource.reflect_on_association(association.to_sym)
            resource.klass.columns.each do |column|
              if !(column.respond_to?(:array) && column.array) &&
                (column.type == :string || column.type == :text)
                column_name = format_column_name(resource.table_name,
                  column.name)
                conditions << "LOWER(#{column_name}) LIKE " +
                  "'%#{@params[:search].downcase}%'"
              end
            end
          end
        end

        @records = @resource.where(conditions.join(' OR '))
      end

      @records
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
      @resource.respond_to?(:acts_as_taggable) &&
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

      operator_date_interval_parser = OperatorDateIntervalParser.new(value,
        @params[:timezone])
      if operator_date_interval_parser.is_interval_date_value()
        filter = operator_date_interval_parser.get_interval_date_filter()
        @records = @records.where("#{association.table_name}.#{subfield} #{filter}")
      else
        where = "#{association.table_name}.#{subfield} #{operator}"
        where += " '#{value}'" if value
        @records = @records.where(where)
      end
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
