class Forest::IslandsController < ForestLiana::SmartActionsController
  def test
    render json: { success: 'You are OK.' }
  end

  def unknown_action
    render json: { success: 'unknown action' }
  end
end
