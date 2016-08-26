module ForestLiana
  class IntercomConversationsGetter
    def initialize(params)
      @params = params
      @app_id = ForestLiana.integrations[:intercom][:app_id]
      @api_key = ForestLiana.integrations[:intercom][:api_key]

      @intercom = ::Intercom::Client.new(app_id: @app_id, api_key: @api_key)
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

        conversation.link = link(conversation)

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
      end
    end

    private

    def collection
      @params[:collection].singularize.capitalize.constantize
    end

    def link(conversation)
      "#{@intercom.base_url}/a/apps/#{@app_id}/inbox/all/conversations/#{conversation.id}"
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
