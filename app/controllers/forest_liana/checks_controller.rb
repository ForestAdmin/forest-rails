module ForestLiana
  class ChecksController < ActionController::Base
    if Rails::VERSION::MAJOR < 4
      before_filter :authenticate_requester_from_jwt, :find_resource
    else
      before_action :authenticate_requester_from_jwt, :find_resource
    end

    def show
      data = ActiveSupport::JSON.decode(request.body.read())
      interval_start = data['intervalStart']
      interval_end = data['intervalEnd']
      field = data['fieldName']

      count = @resource
        .where("#{field} >= ?", Time.at(interval_start).to_datetime)
        .where("#{field} < ?", Time.at(interval_end).to_datetime)
        .count

      render json: { alert: count > 0 }
    end

    private

    def authenticate_requester_from_jwt
      if request.headers['Authorization']
        begin
          token = request.headers['Authorization'].split.second
          JWT.decode(token, ForestLiana.env_secret, true, {
            algorithm: 'HS256',
            leeway: 30
          }).try(:first)
        rescue JWT::ExpiredSignature, JWT::VerificationError
          render status: :unauthorized, json: { error: 'expired_token' },
            serializer: nil
        end
      else
        head :unauthorized
      end
    end

    def find_resource
      @resource = SchemaUtils.find_model_from_table_name(params[:collection])

      if @resource.nil? || !SchemaUtils.model_included?(@resource) ||
          !@resource.ancestors.include?(ActiveRecord::Base)
        render status: :not_found, json: { status: 404 }, serializer: nil
      end
    end
  end
end
