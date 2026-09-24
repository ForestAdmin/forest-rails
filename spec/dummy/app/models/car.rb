class Car < GarageRecord
  belongs_to :driver

  # Cross-database and keyed on a column that is not Driver's primary key: the shape
  # serializer_factory's has_one_relationships branch intercepts.
  belongs_to :pilot, class_name: 'Driver', primary_key: :firstname, foreign_key: :model,
             optional: true
end
