module ForestLiana
  class IntercomConversationGetter
    attr_accessor :record

    def initialize(params)
      @params = params
      @access_token = ForestLiana.integrations[:intercom][:access_token]
      @intercom = ::Intercom::Client.new(token: @access_token)
    end

    def perform
      begin
        @record = @intercom.conversations.find(id: @params[:conversation_id])
      rescue Intercom::ResourceNotFound
        @record = nil
      rescue Intercom::UnexpectedError => exception
        FOREST_LOGGER.error "Cannot retrieve the Intercom conversation: #{exception.message}"
        @record = nil
#         @record = ::Intercom::Conversation.new({
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
      end
    end
  end
end
