class GarageRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :garage, reading: :garage }
end