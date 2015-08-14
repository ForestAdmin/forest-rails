module ForestLiana
  class ResourcesGetter
    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @records_without_sort = @records = search_query
      @records = sort_query
    end

    def records
      @records.offset(offset).limit(limit).to_a
    end

    def count
      @records_without_sort.count
    end

    private

    def search_query
      SearchQueryBuilder.new(@resource.includes(includes), @params).perform
    end

    def sort_query
      if @params[:sort]
        @params[:sort].split(',').each do |field|
          order = detect_sort_order(@params[:sort])
          field.slice!(0) if order == :desc
          field = detect_reference(field)

          association = @resource.reflect_on_association(field.to_sym)
          if association.try(:macro) == :has_many
            if association.options[:through]
              @records = has_many_through_sort(association, order)
            else
              @records = has_many_sort(association, order)
            end
          elsif association.try(:macro) == :has_and_belongs_to_many
            @records = has_and_belongs_to_many(association, order)
          else
            @records = @records.order("#{field} #{order.upcase}")
          end
        end
      elsif @resource.column_names.include?('created_at')
        @records = @records.order('created_at DESC')
      elsif @resource.column_names.include?('id')
        @records = @records.order("#{@resource.table_name}.id DESC")
      else
        @records
      end

      @records
    end

    def has_many_sort(association, order)
      @records
        .select("t1.*, COUNT(t2.id) has_many_count")
        .joins("AS t1 LEFT JOIN #{association.klass.table_name} AS t2
               ON t1.id = t2.#{association.foreign_key}")
      .group("t1.id")
      .order("has_many_count #{order.upcase}")
    end

    def has_many_through_sort(association, order)
      @records
        .select("t1.*, COUNT(t3.id) has_many_count")
        .joins("AS t1 LEFT JOIN #{association.options[:through]} AS t2
               ON t1.id = t2.#{association.active_record.name.foreign_key}")
        .joins("LEFT JOIN #{association.klass.table_name} AS t3
               ON t3.#{association.foreign_key} = t2.id")
      .group("t1.id")
      .order("has_many_count #{order.upcase}")
    end

    def has_and_belongs_to_many(association, order)
      @records
        .select("t1.*, COUNT(t3.id) has_many_count")
        .joins("AS t1 LEFT JOIN #{association.options[:join_table]} AS t2
               ON t1.id = t2.#{association.foreign_key}")
        .joins("LEFT JOIN #{association.klass.table_name} AS t3
               ON t3.id = t2.#{association.options[:association_foreign_key] ||
                association.klass.name.foreign_key}")
      .group("t1.id")
      .order("has_many_count #{order.upcase}")
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

    def includes
      SchemaUtils.associations(@resource).select {|x| !x.options[:through]}
        .map(&:name)
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
