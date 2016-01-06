module ForestLiana
  class IntercomController < ForestLiana::ApplicationController
    def user_conversations
      getter = IntercomConversationsGetter.new(params)
      getter.perform

      render json: serialize_models(getter.records, { count: getter.count })
    end

    def attributes
      getter = IntercomAttributesGetter.new(params)
      getter.perform

      render json: serialize_model(getter.records)
    end
  end
end
