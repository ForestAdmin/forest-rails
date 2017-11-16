module ForestLiana
  class IntercomConversationsGetter < IntegrationBaseGetter
    def initialize(params)
      @params = params
      @access_token = ForestLiana.integrations[:intercom][:access_token]
      @intercom = ::Intercom::Client.new(token: @access_token)
    end

    def count
      @records.count
    end

    def records
      @records[pagination].map do |conversation|
        if conversation.assignee.is_a?(::Intercom::Admin)
          admins = @intercom.admins.all.detect(id: conversation.assignee.id)
          conversation.assignee = admins.first
        end
        conversation
      end
    end

    def perform
      begin
        resource = collection.find(@params[:id])
        @records = @intercom.conversations.find_all(
          email: resource.email,
          type: 'user',
          display_as: 'plaintext',
        ).entries
      rescue Intercom::ResourceNotFound
        @records = []
      rescue Intercom::UnexpectedError => exception
        FOREST_LOGGER.error "Cannot retrieve the Intercom conversations: #{exception.message}"
        @records = []
      end
    end

    private

    def pagination
      offset..(offset + limit - 1)
    end

    def offset
      return 0 unless pagination?

      number = @params[:page][:number]
      if number && number.to_i > 0
        (number.to_i - 1) * limit
      else
        0
      end
    end
  end
end
