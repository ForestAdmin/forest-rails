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

      @records
    end

    def search_param
      if @params[:search]
        conditions = []

        @resource.columns.each_with_index do |column, index|
          if column.name == 'id'
            conditions << "#{@resource.table_name}.id =
              #{@params[:search].to_i}"
          elsif !column.array && (column.type == :string ||
                                  column.type == :text)
            conditions <<
              "\"#{column.name}\" ILIKE '%#{@params[:search].downcase}%'"
          end
        end

        @records = @resource.where(conditions.join(' OR '))
      end

      @records
    end

    def filter_param
      if @params[:filter]
        @params[:filter].each do |field, values|
          next if association?(field)
          values.split(',').each do |value|
            operator, value = OperatorValueParser.parse(value)
            @records = OperatorValueParser.add_where(@records, field, operator,
                                                     value)
          end
        end
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

      where = "#{association.table_name}.#{subfield} #{operator}"
      where += " '#{value}'" if value

      @records = @records
        .joins(field.to_sym)
        .where(where)
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
