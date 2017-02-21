module ForestLiana
  class IntercomAttributesGetter
    attr_accessor :records

    def initialize(params)
      @params = params
      @intercom = ::Intercom::Client.new(
        app_id: ForestLiana.integrations[:intercom][:app_id],
        api_key: ForestLiana.integrations[:intercom][:api_key])
    end

    def count
      @records.count
    end

    def perform
      begin
        resource = collection.find(@params[:id])
        user = @intercom.users.find(email: resource.email)

        user.segments = user.segments.map do |segment|
          @intercom.segments.find(id: segment.id)
        end

        @records = user
      rescue Intercom::ResourceNotFound
      end
    end

    private

    def collection
      @params[:collection].singularize.camelize.constantize
    end
  end
end
