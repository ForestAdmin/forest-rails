module ForestLiana
  class DeviseController < ForestLiana::ApplicationController
    def change_password
      resource = SchemaUtils.find_model_from_table_name(
        params.dig('data', 'attributes', 'collection_name'))

      user = resource.find(params.dig('data', 'attributes', 'ids').first)
      user.password = params.dig('data', 'attributes', 'values', 'New password')
      user.save

      if user.valid?
        head :no_content
      else
        render status: 400, json: {
          error: user.errors.try(:messages).try(:[], :password)
        }
      end
    end
  end
end

