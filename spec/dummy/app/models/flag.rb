class Flag < ActiveRecord::Base
  belongs_to :island, optional: true
end
