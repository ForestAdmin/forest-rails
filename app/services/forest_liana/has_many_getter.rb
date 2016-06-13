module ForestLiana
  class HasManyGetter
    def initialize(resource, association, params)
      @resource = resource
      @association = association
      @params = params
    end

    def perform
      @records = @resource
        .unscoped
        .find(@params[:id])
        .send(@params[:association_name])
      @records = sort_query
    end

    def records
      @records.limit(limit).offset(offset)
    end

    def count
      @records.to_a.length
    end

    private

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

    def sort_query
      if @params[:sort]
        field = @params[:sort]
        order = detect_sort_order(field)
        field.slice!(0) if order == :desc

        @records = @records
          .order("#{@params[:association_name]}.#{field} #{order.upcase}")
      else
        @records
      end
    end

    def detect_sort_order(field)
      return (if field[0] == '-' then :desc else :asc end)
    end

  end
end
