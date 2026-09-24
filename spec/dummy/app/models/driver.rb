class Driver < UserRecord
  has_one :car

  # The inverse of Car#pilot: the preload reads "firstname" off this row, and nothing projects it.
  has_one :piloted_car, class_name: 'Car', primary_key: :firstname, foreign_key: :model
end
