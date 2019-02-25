class Tree < ActiveRecord::Base
  belongs_to :owner, class_name: 'User', inverse_of: :trees_owned
  belongs_to :cutter, class_name: 'User', inverse_of: :trees_cut
  belongs_to :island
end
