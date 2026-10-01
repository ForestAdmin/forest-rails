class Captain < ActiveRecord::Base
  has_one :license, primary_key: :license_number, foreign_key: :number
end
