class Driver < UserRecord
  has_one :car

  # The inverse of Car#pilot: cross-database and keyed on a column that is neither side's primary
  # key, so the preload reads "firstname" off this row — the shape select_foreign_keys names
  # nothing for.
  has_one :piloted_car, class_name: 'Car', primary_key: :firstname, foreign_key: :model
end
