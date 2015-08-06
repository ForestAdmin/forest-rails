module ForestLiana
  class ResourcesGetter
    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def perform
      @records = search_query
      @records = sort_query
    end

    def records
      @records.offset(offset).limit(limit)
    end

    def count
      @records.count
    end

    private

    def search_query
      SearchQueryBuilder.new(@resource.includes(includes), @params).perform
    end

    def sort_query
      query = nil

      if @params[:sort]
        @params[:sort].split(',').each do |field|
          order = detect_sort_order(@params[:sort])
          field.slice!(0) if order == :desc
          field = detect_reference(field)

          query = "#{field} #{order.upcase}"
        end
      elsif @resource.column_names.include?('created_at')
        query = 'created_at DESC'
      elsif @resource.column_names.include?('id')
        query = 'id DESC'
      else
        return @records
      end

      @records.order(query)
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
          "#{association.class_name.to_s.underscore.pluralize}.#{field}"
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
