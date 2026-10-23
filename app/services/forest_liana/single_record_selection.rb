module ForestLiana
  module SingleRecordSelection
    MESSAGE = 'This action can only be triggered on one record at a time.'

    def self.allowed?(action, attributes)
      return true unless action&.type == 'single'

      !attributes[:all_records] && Array(attributes[:ids]).length == 1
    end
  end
end
