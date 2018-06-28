module ForestLiana
  class IntercomController < ForestLiana::ApplicationController
    def conversations
      getter = IntercomConversationsGetter.new(params)
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('intercom_conversations') },
        meta: { count: getter.count }
      })
    end

    def conversation
      getter = IntercomConversationGetter.new(params)
      getter.perform

      render serializer: nil, json: serialize_model(getter.record, {
        context: { type: get_serializer_type('intercom_conversations') }
      })
    end

    def attributes
      getter = IntercomAttributesGetter.new(params)
      getter.perform

      render serializer: nil, json: serialize_model(getter.record, {
        context: { type: get_serializer_type('intercom_attributes') }
      })
    end

    def get_serializer_type(suffix)
      "#{params[:collection]}_#{suffix}"
    end
  end
end
