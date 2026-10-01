class Boat < ActiveRecord::Base
  belongs_to :harbor
  belongs_to :captain

  # Its second hop is keyed on captains.license_number, which the preloader reads off the captain
  # rows: narrowed ones when Harbor's boats related list joins captain to sort on it.
  has_one :captain_license, through: :captain, source: :license
end
