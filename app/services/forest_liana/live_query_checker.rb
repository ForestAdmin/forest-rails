module ForestLiana
  class LiveQueryChecker
    QUERY_SELECT = /\ASELECT\s.*FROM\s.*\z/im

    def self.validate(query)
      raise ForestLiana::Errors::LiveQueryError.new('You cannot execute an empty SQL query.') if query.blank?

      if query.include?(';') && query.index(';') < (query.length - 1)
        raise ForestLiana::Errors::LiveQueryError.new('You cannot chain SQL queries.')
      end
      raise ForestLiana::Errors::LiveQueryError.new('Only SELECT queries are allowed.') if QUERY_SELECT.match(query).nil?
    end
  end
end
