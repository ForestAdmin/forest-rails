module ForestLiana
  class IntercomController < ForestLiana::ApplicationController
    def user_conversations
      getter = IntercomConversationsGetter.new(params)
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        context: { type: get_serializer_type('intercom_conversations') },
        count: getter.count
      })
    end

    def attributes
      getter = IntercomAttributesGetter.new(params)
      getter.perform

      render serializer: nil, json: serialize_model(getter.records, {
        context: { type: get_serializer_type('intercom_attributes') }
      })
    end

    def get_serializer_type(suffix)
      "#{params[:collection]}_#{suffix}"
    end
  end
end
