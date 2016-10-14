module ForestLiana
  class SearchQueryBuilder

    def initialize(resource, params)
      @resource = @records = resource
      @params = params
    end

    def perform
      @records = search_param
      @records = filter_param
      @records = has_many_filter
      @records = belongs_to_filter

      if @params[:search]
        schema.fields.each do |field|
          if field.try(:[], :search)
            @records = field[:search].call(@records, @params[:search])
          end
        end
      end

      @records
    end

    def search_param
      if @params[:search]
        conditions = []

        @resource.columns.each_with_index do |column, index|
          if column.name == 'id'
            if column.type == :integer
              conditions << "#{@resource.table_name}.id =
                #{@params[:search].to_i}"
            else
              conditions << "#{@resource.table_name}.id =
                '#{@params[:search]}'"
            end
          # NOTICE: Rails 3 do not have a defined_enums method
          elsif @resource.respond_to?(:defined_enums) &&
            @resource.defined_enums.has_key?(column.name) &&
            !@resource.defined_enums[column.name][@params[:search].downcase].nil?
            conditions << "\"#{@resource.table_name}\".\"#{column.name}\" =
              #{@resource.defined_enums[column.name][@params[:search].downcase]}"
          elsif !column.array && (column.type == :string ||
                                  column.type == :text)
            conditions <<
              "LOWER(\"#{@resource.table_name}\".\"#{column.name}\") LIKE " +
              "'%#{@params[:search].downcase}%'"
          end
        end

        SchemaUtils.one_associations(@resource).map(&:name).each do |association|
          resource = @resource.reflect_on_association(association.to_sym)
          resource.klass.columns.each do |column|
            if !column.array && (column.type == :string || column.type == :text)
              conditions <<
                "LOWER(\"#{resource.table_name}\".\"#{column.name}\") LIKE " +
                "'%#{@params[:search].downcase}%'"
            end
          end
          @resource = @resource.eager_load(association.to_sym)
        end

        @records = @resource.where(conditions.join(' OR '))
      end

      @records
    end

    def filter_param
      if @params[:filterType] && @params[:filter]
        conditions = []
        @params[:filter].each do |field, values|
          next if association?(field)

          values.split(',').each do |value|
            operator, value = OperatorValueParser.parse(value)
            conditions << OperatorValueParser.get_condition(field, operator,
              value, @resource)
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

    def has_many_filter
      if @params[:filter]
        @params[:filter].each do |field, values|
          next unless has_many_association?(field)

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

      @records = @records
        .joins(field.to_sym)

      operator_date_interval_parser = OperatorDateIntervalParser.new(value)
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

    def schema
      ForestLiana.apimap.find {|x| x.name == @resource.table_name}
    end
  end
end
