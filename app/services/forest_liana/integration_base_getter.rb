module ForestLiana
  class IntegrationBaseGetter
    private

    def pagination?
      @params[:page] && @params[:page][:number]
    end

    def limit
      return 10 unless pagination?

      if @params[:page][:size]
        @params[:page][:size].to_i
      else
        10
      end
    end

    def collection
      @params[:collection].singularize.camelize.constantize
    end
  end
end
