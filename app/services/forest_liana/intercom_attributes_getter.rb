module ForestLiana
  class IntercomAttributesGetter < IntegrationBaseGetter
    attr_accessor :record

    def initialize(params)
      @params = params
      @intercom = ::Intercom::Client.new(token: ForestLiana.integrations[:intercom][:access_token])
    end

    def perform
      begin
        resource = collection.find(@params[:id])
        user = @intercom.users.find(email: resource.email)

        user.segments = user.segments.map do |segment|
          @intercom.segments.find(id: segment.id)
        end
        @record = user
      rescue Intercom::ResourceNotFound
      rescue Intercom::UnexpectedError => exception
        FOREST_LOGGER.error "Cannot retrieve the Intercom attributes: #{exception.message}"
      end
    end
  end
end
