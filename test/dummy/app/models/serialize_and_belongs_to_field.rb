class SerializeAndBelongsToField < ActiveRecord::Base
  serialize :field, Array

  belongs_to :has_one_field
end
