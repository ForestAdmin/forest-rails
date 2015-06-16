class PolymorphicField < ActiveRecord::Base
  belongs_to :has_one_field, polymorphic: true
end
