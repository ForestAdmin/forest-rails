class Car < GarageRecord
  belongs_to :driver

  # Cross-database, keyed on a column that is not Driver's primary key.
  belongs_to :pilot, class_name: 'Driver', primary_key: :firstname, foreign_key: :model,
             optional: true
end
