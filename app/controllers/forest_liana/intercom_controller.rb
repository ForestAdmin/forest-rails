module ForestLiana
  class IntercomController < ForestLiana::ApplicationController
    def user_conversations
      getter = IntercomConversationsGetter.new(params)
      getter.perform

      render serializer: nil, json: serialize_models(getter.records, {
        count: getter.count
      })
    end

    def attributes
      getter = IntercomAttributesGetter.new(params)
      getter.perform

      render json: serialize_model(getter.records), serializer: nil
    end
  end
end
