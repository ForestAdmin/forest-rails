class HasManyThroughField < ActiveRecord::Base
  has_many :belongs_to_fields, through: :has_many_fields
  has_many :has_many_fields
end
