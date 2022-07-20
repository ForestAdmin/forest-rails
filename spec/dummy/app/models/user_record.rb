class UserRecord < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :user, reading: :user }
end