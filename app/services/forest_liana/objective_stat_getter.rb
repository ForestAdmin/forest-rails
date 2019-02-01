module ForestLiana
  class ObjectiveStatGetter < ValueStatGetter
    attr_accessor :objective

    def perform
      super
      @record.value = { value: @record.value[:countCurrent] }
    end
  end
end
