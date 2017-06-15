class SerializeAndBelongsToField < ActiveRecord::Base
  serialize :field, Array

  belongs_to :has_one_field
  belongs_to :has_many_field
  belongs_to :has_many_class_name_field
end
