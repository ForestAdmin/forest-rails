class HasManyClassNameField < ActiveRecord::Base
  has_many :foo, class_name: 'BelongsToField'
end
