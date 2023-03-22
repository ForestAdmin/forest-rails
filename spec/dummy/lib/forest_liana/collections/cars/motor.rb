module Forest
  module Cars
    class Motor
      include ForestLiana::Collection

      collection :Cars__Motor

      action 'my_action'
    end
  end
end
