class HasManyField < ActiveRecord::Base
  has_many :belongs_to_fields
  belongs_to :has_many_through_field
end
