class Forest::OwnersController < ForestLiana::ResourcesController
  def count
    if (params[:search])
      deactivate_count_response
    else
      params[:collection] = 'Owner'
      super
    end
  end
end
