class BelongsToField < ActiveRecord::Base
  belongs_to :has_one_field
  belongs_to :has_many_field
  belongs_to :has_many_class_name_field
end
