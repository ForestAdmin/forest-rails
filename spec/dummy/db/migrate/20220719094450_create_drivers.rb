class CreateDrivers < ActiveRecord::Migration[6.0]
  def change
    # See CreateCars: db:migrate replays this file against `user`'s own migration run too.
    return if Driver.connection.table_exists?(:drivers)

    Driver.connection.create_table :drivers do |t|
      t.string :firstname
    end
  end
end
