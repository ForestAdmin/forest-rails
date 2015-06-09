class BelongsToClassNameField < ActiveRecord::Base
  belongs_to :foo, class_name: 'HasOneField'
end
