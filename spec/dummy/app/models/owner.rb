class Owner < ActiveRecord::Base
  has_many :trees

  default_scope { order('hired_at ASC') }
end
