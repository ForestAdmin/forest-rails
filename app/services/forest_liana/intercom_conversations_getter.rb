module ForestLiana
  class IntercomConversationsGetter
    def initialize(params)
      @params = params
      @access_token = ForestLiana.integrations[:intercom][:access_token]
      @intercom = ::Intercom::Client.new(token: @access_token)
    end

    def count
      #return 1
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
#         conv = ::Intercom::Conversation.new({
#   "type": "conversation",
#   "id": "147",
#   "created_at": 1400850973,
#   "updated_at": 1400857494,
#   "waiting_since": 1400857494,
#   "snoozed_until": nil,
#   conversation_message: ::Intercom::Message.new({
#     "type": "conversation_message",
#     "subject": "tot",
#     "body": "<p>Hi Alice,</p>\n\n<p> We noticed you using our Product,  do you have any questions?</p> \n<p>- Jane</p>",
#     "author": {
#       "type": "admin",
#       "id": "25"
#     },
#     "attachments": [
#       {
#         "name": "signature",
#         "url": "http://example.org/signature.jpg"
#       }
#     ]
#   }),
#   "user": {
#     "type": "user",
#     "id": "536e564f316c83104c000020"
#   },
#   "customers": [
#     {
#       "type": "user",
#       "id": "58ff3f670f14ab4f1aa83750"
#     }
#   ],
#   "assignee": {
#     "type": "admin",
#     "id": "25"
#   },
#   "open": true,
#   "state": "open",
#   "read": true,
#   "conversation_parts": {
#     "type": "conversation_part.list",
#     "total_count":1
#   },
#   "tags": { "type": 'tag.list', "tags": [] }
# })
#         @records = [conv]
      end
    end

    private

    def collection
      @params[:collection].singularize.camelize.constantize
    end

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

    def limit
      return 10 unless pagination?

      if @params[:page][:size]
        @params[:page][:size].to_i
      else
        10
      end
    end

    def pagination?
      @params[:page] && @params[:page][:number]
    end
  end
end
