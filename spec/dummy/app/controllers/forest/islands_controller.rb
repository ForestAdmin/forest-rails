class Forest::IslandsController < ForestLiana::SmartActionsController
  def test
    render json: { success: 'You are OK.' }
  end
end
