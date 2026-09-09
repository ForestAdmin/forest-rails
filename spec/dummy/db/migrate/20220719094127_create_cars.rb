class CreateCars < ActiveRecord::Migration[6.0]
  def change
    # `garage` is registered per-environment (3-tier database.yml, required from Rails 8 for
    # `connects_to` to resolve it at all), so db:migrate now discovers it as its own database and
    # replays this same file's migrations_paths against it too — this file already ran once by the
    # time that happens.
    return if Car.connection.table_exists?(:cars)

    Car.connection.create_table :cars do |t|
      t.string :model
      t.references :driver, index: true
    end
  end
end
