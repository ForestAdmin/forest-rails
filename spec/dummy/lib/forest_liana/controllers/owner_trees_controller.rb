class Forest::OwnerTreesController < ForestLiana::AssociationsController
  def count
    if (params[:search])
      deactivate_count_response
    else
      params[:collection] = 'Owner'
      params[:association_name] = 'trees'
      super
    end
  end
end
