class HasManyThroughField < ActiveRecord::Base
  has_many :belongs_to_field, through: :has_many_fields
end
