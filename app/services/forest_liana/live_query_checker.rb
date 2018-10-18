module ForestLiana
  class LiveQueryChecker
    QUERY_SELECT = /\ASELECT\s.*FROM\s.*\z/im

    def initialize(query, context)
      @query = query.strip
      @context = context
    end

    def validate
      raise generate_error 'You cannot execute an empty SQL query.' if @query.blank?

      if @query.include?(';') && @query.index(';') < (@query.length - 1)
        raise generate_error 'You cannot chain SQL queries.'
      end

      raise generate_error 'Only SELECT queries are allowed.' if QUERY_SELECT.match(@query).nil?
    end

    private

    def generate_error message
      error_message = "#{@context}: #{message}"
      FOREST_LOGGER.error(error_message)
      ForestLiana::Errors::LiveQueryError.new(error_message)
    end
  end
end
