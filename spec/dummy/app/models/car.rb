class Car < GarageRecord
  belongs_to :driver

  # Cross-database, keyed on a column that is not Driver's primary key.
  belongs_to :pilot, class_name: 'Driver', primary_key: :firstname, foreign_key: :model,
             optional: true

  # The same, plus a scope: the preloader applies it and a bare find_by does not, so the
  # serializer's two branches only agree once the fallback is aligned on the preloader.
  belongs_to :active_pilot, -> { where.not(firstname: 'retired') }, class_name: 'Driver',
             primary_key: :firstname, foreign_key: :model, optional: true
end
