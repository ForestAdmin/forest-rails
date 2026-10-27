module ForestLiana
  class DeviseController < ForestLiana::SmartActionsController
    rescue_from ActiveRecord::RecordNotFound, with: :render_target_not_found

    def change_password
      attributes = @parameters[:data][:attributes]
      # The inherited scope check skips select-all requests, yet this action still writes ids.first.
      scoped_records = ForestLiana::ScopeManager.apply_scopes_on_records(
        @resource, forest_user, ForestLiana.name_for(@resource), attributes[:timezone]
      )

      user = scoped_records.find(attributes[:ids].first)
      user.password = attributes[:values]['New password']
      user.save

      if user.valid?
        head :no_content
      else
        render status: 400, json: {
          error: user.errors.try(:messages).try(:[], :password)
        }
      end
    end

    private

    def render_target_not_found
      render serializer: nil, json: { error: 'Smart Action: target record not found' }, status: :bad_request
    end
  end
end
