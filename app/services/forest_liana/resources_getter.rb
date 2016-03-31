module ForestLiana
  class ResourcesGetter
    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @records = @resource.unscoped.includes(includes)
      @records = search_query
      @records = sort_query
    end

    def records
      @records.offset(offset).limit(limit).to_a
    end

    def count
      search_query.count
    end

    private

    def search_query
      SearchQueryBuilder.new(@records, @params).perform
    end

    def sort_query
      if @params[:sort]
        @params[:sort].split(',').each do |field|
          order = detect_sort_order(@params[:sort])
          field.slice!(0) if order == :desc

          ref = field.split('.')[0]
          @records = @records.includes(ref) if association?(ref)

          field = detect_reference(field)
          association = @resource.reflect_on_association(field.to_sym)
          if [:has_many, :has_and_belongs_to_many].include?(
            association.try(:macro))
            @records = has_many_sort(association, order)
          else
            @records = @records.order("#{field} #{order.upcase}")
          end
        end
      elsif @resource.column_names.include?('created_at')
        @records = @records.order("#{@resource.table_name}.created_at DESC")
      elsif @resource.column_names.include?('id')
        @records = @records.order("#{@resource.table_name}.id DESC")
      else
        @records
      end

      @records
    end

    def has_many_sort(association, order)
      @records
        .select("#{@resource.table_name}.*,
                COUNT(#{association.table_name}.id)
                #{association.table_name}_has_many_count")
        .joins(ArelHelpers.join_association(@resource, association.name,
                                            Arel::Nodes::OuterJoin))
        .group("#{@resource.table_name}.id")
        .order("#{association.table_name}_has_many_count #{order.upcase}")
    end

    def detect_sort_order(field)
      return (if field[0] == '-' then :desc else :asc end)
    end

    def detect_reference(param)
      ref, field = param.split('.')

      if ref && field
        association = @resource.reflect_on_all_associations
          .find {|a| a.name == ref.to_sym }

        if association
          "#{association.table_name}.#{field}"
        else
          param
        end
      else
        param
      end
    end

    def association?(field)
      @resource.reflect_on_association(field.to_sym).present?
    end

    def includes
      SchemaUtils.one_associations(@resource).map(&:name)
    end

    def offset
      return 0 unless pagination?

      number = @params[:page][:number]
      if number && number.to_i > 0
        (number.to_i - 1) * limit
      else
        0
      end
    end

    def limit
      return 10 unless pagination?

      if @params[:page][:size]
        @params[:page][:size].to_i
      else
        10
      end
    end

    def pagination?
      @params[:page] && @params[:page][:number]
    end

  end
end
