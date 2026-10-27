module ForestLiana
  class DeviseController < ForestLiana::SmartActionsController
    # The inherited checks vouch for a select-all selection as a whole, never for ids.first,
    # the one record written here.
    before_action :refuse_select_all

    def change_password
      attributes = @parameters[:data][:attributes]
      user = @resource.find(attributes[:ids].first)
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

    def refuse_select_all
      return unless @parameters[:data][:attributes][:all_records]

      raise ForestLiana::Errors::HTTP422Error.new('This action cannot be triggered on a select-all selection.')
    end
  end
end
