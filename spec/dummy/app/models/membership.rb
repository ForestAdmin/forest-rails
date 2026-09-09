class Membership < ActiveRecord::Base
  belongs_to :island
  belongs_to :user
end
