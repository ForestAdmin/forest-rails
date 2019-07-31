module ForestLiana
  class IntercomConversationGetter < IntegrationBaseGetter
    attr_accessor :record

    def initialize(params)
      @params = params
      @access_token = ForestLiana.integrations[:intercom][:access_token]
      @intercom = ::Intercom::Client.new(token: @access_token)
    end

    def perform
      begin
        @record = @intercom.conversations.find(id: @params[:conversation_id])
      rescue Intercom::ResourceNotFound => exception
        ForestLiana.error_handler.call(exception)
        @record = nil
      rescue Intercom::UnexpectedError => exception
        ForestLiana.error_handler.call(exception)
        FOREST_LOGGER.error "Cannot retrieve the Intercom conversation: #{exception.message}"
        @record = nil
      end
    end
  end
end
